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
  StreamSubscription<DatabaseEvent>? _playersSub;
  bool _skipNextRemoteUpdate = false;
  bool _initialized = false;

  // Tracks names of players we've seen so we can detect departures.
  Map<String, String> _knownPlayerNames = {};

  // Notified when a player leaves mid-game. Consumed by the UI then cleared.
  String? playerLeftMessage;

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
    _playersSub?.cancel();
    _playersSub = _svc.roomRef(roomCode).child('players').onValue.listen(_onPlayersUpdate);
  }

  @override
  void dispose() {
    _gameSub?.cancel();
    _playersSub?.cancel();
    super.dispose();
  }

  void clearPlayerLeftMessage() {
    playerLeftMessage = null;
  }

  // ──────────────────────────────────────────────
  // Remote state application
  // ──────────────────────────────────────────────

  bool _isApplyingRemoteState = false;

  Future<void> _onRemoteGameUpdate(DatabaseEvent event) async {
    if (_skipNextRemoteUpdate) {
      _skipNextRemoteUpdate = false;
      return;
    }
    final data = event.snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return;

    // Skip if currently animating a remote move; Firebase RTDB will
    // re-emit the latest state when the subscription catches up.
    if (_isApplyingRemoteState) return;

    _isApplyingRemoteState = true;
    try {
      await _applyRemoteState(data);
    } finally {
      _isApplyingRemoteState = false;
    }

    // If it's now an AI turn and we're the host, drive it.
    if (isHost && playerModes[currentPlayer] == PlayerMode.ai) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (isMatchActive) _checkAndExecuteAiTurn();
      });
    } else if (isHost && playerModes[currentPlayer] == PlayerMode.absent) {
      // Skip absent (non-participating) color slot.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (isMatchActive) _doNextTurn();
      });
    }
  }

  // Detect players leaving the room mid-game.
  void _onPlayersUpdate(DatabaseEvent event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) {
      // Room was deleted (host left).
      if (_knownPlayerNames.isNotEmpty && isMatchActive) {
        playerLeftMessage = 'Host left the game';
        notifyListeners();
      }
      return;
    }

    final current = <String, String>{};
    for (final entry in data.entries) {
      final uid = entry.key as String;
      final playerData = entry.value as Map<dynamic, dynamic>;
      current[uid] = playerData['name'] as String? ?? 'Player';
    }

    // Check for players who disappeared since last update.
    for (final entry in _knownPlayerNames.entries) {
      if (entry.key != localUid && !current.containsKey(entry.key)) {
        playerLeftMessage = '${entry.value} left the game';
        notifyListeners();
      }
    }

    _knownPlayerNames = current;
  }

  Future<void> _applyRemoteState(Map<dynamic, dynamic> data) async {
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

    // Pieces – detect if one piece moved forward (animate it step-by-step)
    final rawPieces = data['pieces'] as Map<dynamic, dynamic>?;
    if (rawPieces != null) {
      // Build a map of new positions
      final Map<String, int> newPositions = {};
      for (final entry in rawPieces.entries) {
        final key = entry.key as String;
        final pieceData = entry.value as Map<dynamic, dynamic>?;
        if (pieceData != null) {
          newPositions[key] = (pieceData['progress'] as num?)?.toInt() ?? -1;
        }
      }

      // Find the piece that moved forward (candidate for step-by-step animation).
      // Only animate moves of 1–6 steps from an on-board position, or an
      // unlock from base (-1 → 0).
      PieceModel? pieceToAnimate;
      int? animateTarget;

      for (final p in pieces) {
        final key = '${p.type.name}_${p.id}';
        final newProg = newPositions[key];
        if (newProg == null || newProg == p.progress) continue;

        final diff = newProg - p.progress;
        if (p.progress == -1 && newProg == 0) {
          pieceToAnimate = p;
          animateTarget = 0;
          break;
        } else if (diff > 0 && diff <= 6 && p.progress >= 0) {
          pieceToAnimate = p;
          animateTarget = newProg;
          break;
        }
      }

      if (pieceToAnimate != null && animateTarget != null) {
        // Apply all other piece changes immediately (captures etc.)
        for (final p in pieces) {
          if (p == pieceToAnimate) continue;
          final key = '${p.type.name}_${p.id}';
          final newProg = newPositions[key];
          if (newProg != null) p.progress = newProg;
        }

        if (!_initialized) {
          _initialized = true;
          isMatchActive = true;
        }
        _recalcMovablePieces();
        notifyListeners();

        // Animate the moving piece
        if (pieceToAnimate.progress == -1 && animateTarget == 0) {
          // Unlock from base
          pieceToAnimate.progress = 0;
          AudioManager().playMove();
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 250));
        } else {
          final startProg = pieceToAnimate.progress;
          for (int i = startProg + 1; i <= animateTarget!; i++) {
            if (!isMatchActive) {
              // Match ended mid-animation – snap to final positions immediately.
              for (final p in pieces) {
                final key = '${p.type.name}_${p.id}';
                final newProg = newPositions[key];
                if (newProg != null) p.progress = newProg;
              }
              notifyListeners();
              return;
            }
            pieceToAnimate.progress = i;
            AudioManager().playMove();
            notifyListeners();
            await Future.delayed(const Duration(milliseconds: 250));
          }
        }

        // After animation, reconcile final positions (handles captures that
        // occurred at the destination).
        bool caughtSomeone = false;
        for (final p in pieces) {
          final key = '${p.type.name}_${p.id}';
          final newProg = newPositions[key];
          if (newProg != null && newProg != p.progress) {
            if (newProg == -1 && p.progress >= 0) caughtSomeone = true;
            p.progress = newProg;
          }
        }
        if (caughtSomeone) AudioManager().playCapture();
      } else {
        // No animated piece – apply all positions directly.
        for (final p in pieces) {
          final key = '${p.type.name}_${p.id}';
          final newProg = newPositions[key];
          if (newProg != null) p.progress = newProg;
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
      AudioManager().playMove();
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 250));
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

      final int totalActive = PlayerType.values
          .where((p) => playerModes[p] != PlayerMode.absent)
          .length;
      final int activeWinners =
          winners.where((w) => playerModes[w] != PlayerMode.absent).length;

      if (activeWinners >= totalActive - 1) {
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

    int safety = 0;
    while (safety < 4 &&
        (winners.contains(currentPlayer) ||
            playerModes[currentPlayer] == PlayerMode.absent)) {
      next = (next + 1) % 4;
      currentPlayer = PlayerType.values[next];
      safety++;
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
    if (playerModes[currentPlayer] == PlayerMode.ai) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!isMatchActive) return;
      await rollDice();
    } else if (playerModes[currentPlayer] == PlayerMode.absent) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!isMatchActive) return;
      await _doNextTurn();
    }
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

    // Seed known player names for leave-detection.
    _knownPlayerNames = {
      for (final p in players.values) p.uid: p.name,
    };

    for (final color in PlayerType.values) {
      final matchingPlayer =
          players.values.where((p) => p.color == color.name).firstOrNull;

      if (matchingPlayer == null) {
        playerModes[color] = PlayerMode.absent;
      } else if (matchingPlayer.isAi) {
        playerModes[color] = PlayerMode.ai;
      } else {
        playerModes[color] = PlayerMode.online;
        // Populate display info for human players.
        playerDisplayNames[color] = matchingPlayer.name;
        playerDisplayAvatars[color] = matchingPlayer.avatar;
      }
    }

    startListening();
  }

  @override
  void quitMatch() {
    isMatchActive = false;
    _gameSub?.cancel();
  }
}
