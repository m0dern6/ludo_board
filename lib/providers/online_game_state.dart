import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import '../models/piece_model.dart';
import '../models/online_models.dart';
import '../constants/path_constants.dart';
import '../services/online_service.dart';
import '../services/audio_manager.dart';
import 'game_state.dart';

/// Online variant of [GameState] that syncs moves with Firebase RTDB.
///
/// Architecture:
///  • The local player (and the host for AI players) performs moves and writes
///    the full game state to RTDB after every action.
///  • All clients (including the writer) listen to the RTDB stream. The
///    [_skipNextRemoteUpdate] flag prevents the writer from double-applying
///    their own write.
class OnlineGameState extends GameState {
  final String roomCode;
  final String localUid;
  PlayerType localColor;
  final bool isHost;
  final Map<String, OnlinePlayer> roomPlayers;

  final OnlineService _svc = OnlineService();
  StreamSubscription<DatabaseEvent>? _gameSub;
  bool _skipNextRemoteUpdate = false;
  bool _initialized = false;

  OnlineGameState({
    required this.roomCode,
    required this.localUid,
    required this.localColor,
    required this.isHost,
    required this.roomPlayers,
  });

  // ──────────────────────────────────────────────
  // Setup & teardown
  // ──────────────────────────────────────────────

  void startListening() {
    _gameSub?.cancel();
    _gameSub = _svc.gameStream(roomCode).listen(_onRemoteGameUpdate);
  }

  @override
  void dispose() {
    _gameSub?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // Remote state application
  // ──────────────────────────────────────────────

  void _onRemoteGameUpdate(DatabaseEvent event) {
    if (_skipNextRemoteUpdate) {
      _skipNextRemoteUpdate = false;
      return;
    }
    final data = event.snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return;

    _applyRemoteState(data);

    // If it's now an AI turn and we're the host, drive it.
    if (isHost && playerModes[currentPlayer] == PlayerMode.ai) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (isMatchActive) _checkAndExecuteAiTurn();
      });
    }
  }

  void _applyRemoteState(Map<dynamic, dynamic> data) {
    // Current player
    final cpStr = data['currentPlayer'] as String? ?? 'red';
    currentPlayer = PlayerType.values.firstWhere(
      (p) => p.name == cpStr,
      orElse: () => PlayerType.red,
    );

    diceValue = (data['diceValue'] as num?)?.toInt() ?? 0;
    isDiceRolling = data['isDiceRolling'] as bool? ?? false;
    sixCount = (data['sixCount'] as num?)?.toInt() ?? 0;

    final statusStr = data['status'] as String? ?? 'rolling';
    status = GameStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => GameStatus.rolling,
    );

    // Winners
    final rawWinners = data['winners'];
    winners = [];
    if (rawWinners is List) {
      for (final w in rawWinners) {
        final t = PlayerType.values.firstWhere(
          (p) => p.name == w,
          orElse: () => PlayerType.red,
        );
        if (!winners.contains(t)) winners.add(t);
      }
    }

    // hasKilled
    final rawKilled = data['hasKilled'] as Map<dynamic, dynamic>?;
    if (rawKilled != null) {
      for (final entry in rawKilled.entries) {
        final t = PlayerType.values.firstWhere(
          (p) => p.name == entry.key,
          orElse: () => PlayerType.red,
        );
        hasKilled[t] = entry.value as bool? ?? false;
      }
    }

    // Pieces
    final rawPieces = data['pieces'] as Map<dynamic, dynamic>?;
    if (rawPieces != null) {
      for (final p in pieces) {
        final key = '${p.type.name}_${p.id}';
        final pieceData = rawPieces[key] as Map<dynamic, dynamic>?;
        if (pieceData != null) {
          p.progress = (pieceData['progress'] as num?)?.toInt() ?? -1;
        }
      }
    }

    if (!_initialized) {
      _initialized = true;
      isMatchActive = true;
    }

    _recalcMovablePieces();
    notifyListeners();
  }

  void _recalcMovablePieces() {
    if (status == GameStatus.selecting) {
      _calculateMovablePiecesInternal();
    } else {
      movablePieces = [];
    }
  }

  void _calculateMovablePiecesInternal() {
    if (winners.contains(currentPlayer)) {
      movablePieces = [];
      return;
    }
    movablePieces = pieces.where((p) => p.type == currentPlayer).where((p) {
      if (p.progress == -1) return diceValue == 6;
      if (rules.mustKillToEnterHome && !hasKilled[currentPlayer]!) {
        if (p.progress + diceValue > 50) return false;
      }
      if (p.progress + diceValue > 56) return false;
      return true;
    }).toList();
  }

  // ──────────────────────────────────────────────
  // Helpers to write state to RTDB
  // ──────────────────────────────────────────────

  Future<void> _writeGameState() async {
    _skipNextRemoteUpdate = true;
    final winnersJson = winners.map((w) => w.name).toList();
    final piecesMap = <String, dynamic>{};
    for (final p in pieces) {
      piecesMap['${p.type.name}_${p.id}'] = {'progress': p.progress};
    }
    final hasKilledMap = hasKilled.map((k, v) => MapEntry(k.name, v));

    await _svc.writeGameState(roomCode, {
      'currentPlayer': currentPlayer.name,
      'diceValue': diceValue,
      'status': status.name,
      'isDiceRolling': isDiceRolling,
      'sixCount': sixCount,
      'winners': winnersJson,
      'hasKilled': hasKilledMap,
      'pieces': piecesMap,
    });
  }

  // ──────────────────────────────────────────────
  // Override: rollDice
  // ──────────────────────────────────────────────

  @override
  Future<void> rollDice() async {
    if (!isMatchActive || isDiceRolling || status != GameStatus.rolling) return;

    // Guard: only the current player (or host for AI) may roll
    final isLocalTurn = currentPlayer == localColor;
    final isAiTurn = playerModes[currentPlayer] == PlayerMode.ai;
    if (!isLocalTurn && !(isAiTurn && isHost)) return;

    isDiceRolling = true;
    AudioManager().playDice();
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!isMatchActive) return;

    diceValue = Random().nextInt(6) + 1;
    isDiceRolling = false;

    if (diceValue == 6) {
      sixCount++;
      if (sixCount == 3) {
        sixCount = 0;
        status = GameStatus.moving;
        notifyListeners();
        await _writeGameState();
        await Future.delayed(const Duration(seconds: 1));
        if (!isMatchActive) return;
        await _doNextTurn();
        return;
      }
    } else {
      sixCount = 0;
    }

    _calculateMovablePiecesInternal();

    if (movablePieces.isEmpty) {
      status = GameStatus.moving;
      notifyListeners();
      await _writeGameState();
      await Future.delayed(const Duration(seconds: 1));
      if (!isMatchActive) return;
      await _doNextTurn();
    } else {
      status = GameStatus.selecting;
      notifyListeners();
      await _writeGameState();

      if (isAiTurn && isHost) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!isMatchActive) return;
        await _aiPickPiece();
      }
    }
  }

  // ──────────────────────────────────────────────
  // Override: movePiece
  // ──────────────────────────────────────────────

  @override
  Future<void> movePiece(PieceModel piece) async {
    if (!isMatchActive ||
        status != GameStatus.selecting ||
        !movablePieces.contains(piece)) return;

    final isLocalTurn = currentPlayer == localColor;
    final isAiTurn = playerModes[currentPlayer] == PlayerMode.ai;
    if (!isLocalTurn && !(isAiTurn && isHost)) return;

    status = GameStatus.moving;
    notifyListeners();

    if (piece.progress == -1) {
      piece.progress = 0;
    } else {
      for (int i = 0; i < diceValue; i++) {
        if (!isMatchActive) return;
        piece.progress++;
        AudioManager().playMove();
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }

    if (!isMatchActive) return;

    bool caughtSomeone = _checkCollisionsInternal(piece);
    if (caughtSomeone) {
      hasKilled[currentPlayer] = true;
      AudioManager().playCapture();
    }

    int winCount = rules.quickMode ? 2 : 4;
    bool allFinished =
        pieces.where((p) => p.type == piece.type && p.progress == 56).length >=
            winCount;

    if (allFinished && !winners.contains(piece.type)) {
      winners.add(piece.type);
      if (winners.length == 3) {
        AudioManager().playVictory();
        for (final pType in PlayerType.values) {
          if (!winners.contains(pType)) winners.add(pType);
        }
        status = GameStatus.finished;
        notifyListeners();
        await _writeGameState();
        return;
      }
    }

    bool extraTurn = false;
    if (diceValue == 6 || piece.progress == 56 || caughtSomeone) {
      extraTurn = true;
    } else if (rules.rediceOnOne && diceValue == 1) {
      extraTurn = true;
    }

    if (extraTurn) {
      status = GameStatus.rolling;
      diceValue = 0;
      notifyListeners();
      await _writeGameState();
      await _checkAndExecuteAiTurn();
    } else {
      await _doNextTurn();
    }
  }

  // ──────────────────────────────────────────────
  // Internal helpers (override base)
  // ──────────────────────────────────────────────

  bool _checkCollisionsInternal(PieceModel movedPiece) {
    if (movedPiece.progress < 0 || movedPiece.progress >= 51) return false;
    int movedGlobal =
        (PathConstants.getStartIdx(movedPiece.type) + movedPiece.progress) % 52;
    if (PathConstants.isSafeGlobalIdx(movedGlobal)) return false;

    bool captured = false;
    for (final other in pieces) {
      if (other.type == movedPiece.type) continue;
      if (other.progress < 0 || other.progress >= 51) continue;
      int otherGlobal =
          (PathConstants.getStartIdx(other.type) + other.progress) % 52;
      if (otherGlobal == movedGlobal) {
        other.progress = -1;
        captured = true;
      }
    }
    return captured;
  }

  Future<void> _doNextTurn() async {
    if (!isMatchActive) return;
    sixCount = 0;
    int idx = PlayerType.values.indexOf(currentPlayer);
    int next = (idx + 1) % 4;
    currentPlayer = PlayerType.values[next];
    while (winners.contains(currentPlayer) && winners.length < 4) {
      next = (next + 1) % 4;
      currentPlayer = PlayerType.values[next];
    }
    status = GameStatus.rolling;
    diceValue = 0;
    movablePieces = [];
    notifyListeners();
    await _writeGameState();
    await _checkAndExecuteAiTurn();
  }

  Future<void> _checkAndExecuteAiTurn() async {
    if (!isMatchActive || status == GameStatus.finished) return;
    if (!isHost) return;
    if (playerModes[currentPlayer] != PlayerMode.ai) return;

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!isMatchActive) return;
    await rollDice();
  }

  Future<void> _aiPickPiece() async {
    if (movablePieces.isEmpty) return;

    PieceModel? selected;
    for (final p in movablePieces) {
      if (p.progress >= 0 && p.progress < 51) {
        int targetPos =
            (PathConstants.getStartIdx(p.type) + p.progress + diceValue) % 52;
        if (!PathConstants.isSafeGlobalIdx(targetPos)) {
          bool willKill = pieces.any((other) =>
              other.type != p.type &&
              other.progress >= 0 &&
              other.progress < 51 &&
              (PathConstants.getStartIdx(other.type) + other.progress) % 52 ==
                  targetPos);
          if (willKill) {
            selected = p;
            break;
          }
        }
      }
    }

    if (selected == null && diceValue == 6) {
      selected = movablePieces.where((p) => p.progress == -1).firstOrNull;
    }
    selected ??= movablePieces
        .reduce((curr, next) => curr.progress > next.progress ? curr : next);

    await movePiece(selected);
  }

  // ──────────────────────────────────────────────
  // Setup (called once when screen loads)
  // ──────────────────────────────────────────────

  /// Configure player modes from the room's player data, then start listening.
  void initFromRoom(Map<String, OnlinePlayer> players, GameRules gameRules) {
    initPieces();
    rules = gameRules;
    isMatchActive = true;

    for (final color in PlayerType.values) {
      final matchingPlayer = players.values.firstWhere(
        (p) => p.color == color.name,
        orElse: () => OnlinePlayer(
          uid: 'ai_${color.name}',
          name: 'AI',
          avatar: 0,
          color: color.name,
          isAi: true,
        ),
      );
      playerModes[color] =
          matchingPlayer.isAi ? PlayerMode.ai : PlayerMode.online;
    }

    startListening();
  }

  @override
  void quitMatch() {
    isMatchActive = false;
    _gameSub?.cancel();
  }
}
