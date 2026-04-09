import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import '../models/online_models.dart';
import '../models/piece_model.dart';

class OnlineService {
  static final OnlineService _instance = OnlineService._internal();
  factory OnlineService() => _instance;
  OnlineService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  DatabaseReference roomRef(String code) => _db.ref('rooms/$code');

  // ──────────────────────────────────────────────
  // Room management
  // ──────────────────────────────────────────────

  /// Generate a unique 6-character alphanumeric room code and create the room.
  Future<String> createRoom({
    required String hostUid,
    required String hostName,
    required int hostAvatar,
    required String hostColor,
    required GameRules rules,
  }) async {
    String code;
    do {
      code = _generateCode();
    } while (await _roomExists(code));

    final ref = roomRef(code);
    await ref.set({
      'host': hostUid,
      'status': 'waiting',
      'createdAt': ServerValue.timestamp,
      'rules': rules.toJson(),
      'players': {
        hostUid: {
          'uid': hostUid,
          'name': hostName,
          'avatar': hostAvatar,
          'color': hostColor,
          'isAi': false,
          'isOnline': true,
        },
      },
    });
    return code;
  }

  /// Diagonal color pairing for fair 2-player games.
  static const Map<String, String> _diagonalColor = {
    'red': 'yellow',
    'yellow': 'red',
    'green': 'blue',
    'blue': 'green',
  };

  /// Join an existing room. Returns an error string or null on success.
  Future<String?> joinRoom({
    required String code,
    required String uid,
    required String name,
    required int avatar,
  }) async {
    final ref = roomRef(code);
    final snapshot = await ref.get();
    if (!snapshot.exists) return 'Room not found.';

    final data = snapshot.value as Map<dynamic, dynamic>;
    if (data['status'] != 'waiting') return 'Game has already started.';

    final players = data['players'] as Map<dynamic, dynamic>? ?? {};
    if (players.length >= 4) return 'Room is full (max 4 players).';
    if (players.containsKey(uid)) return null; // already joined

    final takenColors = players.values
        .map((v) => (v as Map<dynamic, dynamic>)['color'] as String?)
        .whereType<String>()
        .toSet();
    final allColors = ['red', 'green', 'yellow', 'blue'];

    // For the 2nd player, auto-assign the diagonal of the existing player's
    // color so their home bases are always in cross-section.
    String color;
    if (players.length == 1) {
      final existingColor = takenColors.first;
      color = _diagonalColor[existingColor] ??
          allColors.firstWhere((c) => !takenColors.contains(c));
    } else {
      color = allColors.firstWhere((c) => !takenColors.contains(c));
    }

    await ref.child('players/$uid').set({
      'uid': uid,
      'name': name,
      'avatar': avatar,
      'color': color,
      'isAi': false,
      'isOnline': true,
    });
    return null;
  }

  /// Remove a player from the room; if host leaves, delete the room.
  Future<void> leaveRoom(String code, String uid) async {
    final ref = roomRef(code);
    final snapshot = await ref.child('host').get();
    final host = snapshot.value as String?;
    if (host == uid) {
      await ref.remove();
    } else {
      await ref.child('players/$uid').remove();
    }
  }

  /// Mark the player as offline (disconnected).
  Future<void> setPlayerOnline(String code, String uid, bool online) async {
    await roomRef(code).child('players/$uid/isOnline').set(online);
  }

  // ──────────────────────────────────────────────
  // Game start
  // ──────────────────────────────────────────────

  /// Host starts the match. Fills remaining slots with AI players when
  /// [rules.fillWithAi] is true, then writes the initial game state to RTDB.
  Future<void> startGame(String code) async {
    final ref = roomRef(code);
    final snapshot = await ref.get();
    final data = snapshot.value as Map<dynamic, dynamic>;
    final players = Map<String, dynamic>.from(
        (data['players'] as Map<dynamic, dynamic>).cast<String, dynamic>());
    final rules = GameRules.fromJson(
        ((data['rules'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>()) ??
            {});

    // Assign AI for unfilled slots only when fillWithAi is enabled.
    const allColors = ['red', 'green', 'yellow', 'blue'];
    if (rules.fillWithAi) {
      final takenColors = players.values
          .map((v) => (v as Map<dynamic, dynamic>)['color'] as String)
          .toSet();
      int aiIdx = 0;
      for (final color in allColors) {
        if (!takenColors.contains(color)) {
          final aiId = 'ai_$color';
          players[aiId] = {
            'uid': aiId,
            'name': 'AI ${color[0].toUpperCase()}${color.substring(1)}',
            'avatar': aiIdx % 8,
            'color': color,
            'isAi': true,
            'isOnline': true,
          };
          aiIdx++;
        }
      }
    }

    // Build initial pieces state
    final Map<String, dynamic> piecesMap = {};
    for (final color in allColors) {
      for (int i = 0; i < 4; i++) {
        piecesMap['${color}_$i'] = {'progress': -1};
      }
    }

    await ref.update({
      'status': 'playing',
      'players': players,
      'game': {
        'currentPlayer': 'red',
        'diceValue': 0,
        'status': 'rolling',
        'isDiceRolling': false,
        'sixCount': 0,
        'winners': <String>[],
        'hasKilled': {
          'red': false,
          'green': false,
          'yellow': false,
          'blue': false,
        },
        'pieces': piecesMap,
      },
    });
  }

  // ──────────────────────────────────────────────
  // Game state writes (called by OnlineGameState)
  // ──────────────────────────────────────────────

  Future<void> writeGameState(
      String code, Map<String, dynamic> gameState) async {
    await roomRef(code).child('game').update(gameState);
  }

  Future<void> writePieces(
      String code, List<PieceModel> pieces) async {
    final Map<String, dynamic> piecesMap = {};
    for (final p in pieces) {
      piecesMap['${p.type.name}_${p.id}'] = {'progress': p.progress};
    }
    await roomRef(code).child('game/pieces').set(piecesMap);
  }

  // ──────────────────────────────────────────────
  // Room rules update
  // ──────────────────────────────────────────────

  /// Update game rules for a room (host only).
  Future<void> updateRules(String code, GameRules rules) async {
    await roomRef(code).child('rules').update(rules.toJson());
  }

  // ──────────────────────────────────────────────
  // Color change
  // ──────────────────────────────────────────────

  /// Change a player's color. For 2-player rooms the other player's color is
  /// automatically updated to maintain the diagonal-pairing constraint.
  /// Returns an error string or null on success.
  Future<String?> changePlayerColor({
    required String code,
    required String uid,
    required String newColor,
  }) async {
    final ref = roomRef(code);
    final snapshot = await ref.get();
    if (!snapshot.exists) return 'Room not found.';

    final data = snapshot.value as Map<dynamic, dynamic>;
    final players = data['players'] as Map<dynamic, dynamic>? ?? {};

    if (players.length == 2) {
      // Enforce diagonal constraint: auto-update the other player's color.
      final otherUid =
          players.keys.cast<String>().firstWhere((k) => k != uid);
      final diagonalColor = _diagonalColor[newColor]!;
      await ref.child('players/$uid/color').set(newColor);
      await ref.child('players/$otherUid/color').set(diagonalColor);
    } else {
      // 3+ players: just ensure color isn't already taken.
      for (final entry in players.entries) {
        if (entry.key != uid) {
          final player = entry.value as Map<dynamic, dynamic>;
          if (player['color'] == newColor) return 'Color already taken.';
        }
      }
      await ref.child('players/$uid/color').set(newColor);
    }
    return null;
  }

  // ──────────────────────────────────────────────
  // Streams
  // ──────────────────────────────────────────────

  Stream<DatabaseEvent> roomStream(String code) =>
      roomRef(code).onValue;

  Stream<DatabaseEvent> gameStream(String code) =>
      roomRef(code).child('game').onValue;

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<bool> _roomExists(String code) async {
    final snap = await roomRef(code).child('host').get();
    return snap.exists;
  }
}
