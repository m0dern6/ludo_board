import 'dart:math';
import 'package:flutter/material.dart';
import '../models/piece_model.dart';
import '../constants/path_constants.dart';
import '../services/audio_manager.dart';

class GameState extends ChangeNotifier {
  final Random _random = Random();
  List<PieceModel> pieces = [];
  PlayerType currentPlayer = PlayerType.red;
  int diceValue = 0;
  bool isDiceRolling = false;
  GameStatus status = GameStatus.rolling;
  List<PieceModel> movablePieces = [];
  List<PlayerType> winners = [];
  BoardTheme currentTheme = BoardTheme.classic;
  bool musicEnabled = true;
  bool sfxEnabled = true;
  bool isMatchActive = false; // Flag to kill background AI activities

  void setTheme(BoardTheme theme) {
    currentTheme = theme;
    notifyListeners();
  }

  void toggleMusic() {
    musicEnabled = !musicEnabled;
    AudioManager().updateSettings(musicEnabled, sfxEnabled);
    notifyListeners();
  }

  void toggleSfx() {
    sfxEnabled = !sfxEnabled;
    AudioManager().updateSettings(musicEnabled, sfxEnabled);
    notifyListeners();
  }
  
  // Track who is a bot
  Map<PlayerType, PlayerMode> playerModes = {
    PlayerType.red: PlayerMode.human,
    PlayerType.green: PlayerMode.human,
    PlayerType.yellow: PlayerMode.human,
    PlayerType.blue: PlayerMode.human,
  };

  // Optional display info for online players (avatar index + name)
  Map<PlayerType, String> playerDisplayNames = {};
  Map<PlayerType, int> playerDisplayAvatars = {};

  // Game Rules
  GameRules rules = GameRules();
  
  // Track if player has killed an opponent (for mustKillToEnterHome)
  Map<PlayerType, bool> hasKilled = {
    PlayerType.red: false,
    PlayerType.green: false,
    PlayerType.yellow: false,
    PlayerType.blue: false,
  };

  int sixCount = 0;

  GameState() {
    initPieces();
  }

  void initPieces() {
    pieces = [];
    for (var type in PlayerType.values) {
      for (int i = 0; i < 4; i++) {
        pieces.add(PieceModel(id: i, type: type, progress: -1));
      }
    }
    hasKilled = { for (var v in PlayerType.values) v: false };
    sixCount = 0;
  }

  void updateRules(GameRules newRules) {
    rules = newRules;
    notifyListeners();
  }

  void setupGame({
    required Map<PlayerType, PlayerMode> modes,
    required GameRules gameRules,
  }) {
    initPieces();
    playerModes = modes;
    rules = gameRules;
    currentPlayer = PlayerType.red;
    diceValue = 0;
    isDiceRolling = false;
    status = GameStatus.rolling;
    winners = [];
    movablePieces = [];
    isMatchActive = true;
    notifyListeners();
    
    _checkAndExecuteCpuTurn();
  }

  void quitMatch() {
    isMatchActive = false;
  }

  void resetGame() {
    initPieces();
    isMatchActive = true;
    currentPlayer = PlayerType.red;
    diceValue = 0;
    isDiceRolling = false;
    status = GameStatus.rolling;
    winners = [];
    movablePieces = [];
    notifyListeners();
    _checkAndExecuteCpuTurn();
  }

  Future<void> rollDice() async {
    if (!isMatchActive || isDiceRolling || status != GameStatus.rolling) return;
    
    isDiceRolling = true;
    AudioManager().playDice();
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!isMatchActive) return; // Kill if quitted during delay
    
    diceValue = _random.nextInt(6) + 1;
    isDiceRolling = false;
    
    if (diceValue == 6) {
      sixCount++;
      if (sixCount == 3) {
        // Three 6s = turn lost
        sixCount = 0;
        status = GameStatus.moving;
        notifyListeners();
        await Future.delayed(const Duration(seconds: 1));
        if (!isMatchActive) return;
        nextTurn();
        return;
      }
    } else {
      sixCount = 0;
    }

    _calculateMovablePieces();
    
    if (movablePieces.isEmpty) {
      status = GameStatus.moving;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 1));
      if (!isMatchActive) return;
      nextTurn();
    } else {
      status = GameStatus.selecting;
      notifyListeners();
      
    if (playerModes[currentPlayer] == PlayerMode.ai) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!isMatchActive) return;
        _cpuPickPiece();
      }
    }
  }

  void _calculateMovablePieces() {
    if (winners.contains(currentPlayer)) {
      movablePieces = [];
      return;
    }
    movablePieces = pieces.where((p) => p.type == currentPlayer).where((p) {
      if (p.progress == -1) return diceValue == 6;
      
      // Must kill to enter home rule
      if (rules.mustKillToEnterHome && !hasKilled[currentPlayer]!) {
         if (p.progress + diceValue > 50) return false;
      }

      if (p.progress + diceValue > 56) return false;
      return true;
    }).toList();
  }

  Future<void> _cpuPickPiece() async {
    if (movablePieces.isEmpty) return;
    
    PieceModel? selected;
    
    // 1. Can kill?
    for (var p in movablePieces) {
      if (p.progress >= 0 && p.progress < 51) {
        int targetPos = (PathConstants.getStartIdx(p.type) + p.progress + diceValue) % 52;
        if (!PathConstants.isSafeGlobalIdx(targetPos)) {
          bool willKill = pieces.any((other) => 
            other.type != p.type && 
            other.progress >= 0 && 
            other.progress < 51 && 
            (PathConstants.getStartIdx(other.type) + other.progress) % 52 == targetPos
          );
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
    
    if (selected == null) {
      selected = movablePieces.reduce((curr, next) => curr.progress > next.progress ? curr : next);
    }

    if (selected != null) {
      movePiece(selected);
    }
  }

  Future<void> movePiece(PieceModel piece) async {
    if (!isMatchActive || status != GameStatus.selecting || !movablePieces.contains(piece)) return;

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
        // 250ms matches the 200ms hop animation + a 50ms 'landing' pause
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }

    if (!isMatchActive) return; // Guard after movement loop
    bool hasWon = piece.progress == 56;
    bool caughtSomeone = _checkCollisions(piece);
    if (caughtSomeone) {
      hasKilled[currentPlayer] = true;
      AudioManager().playCapture();
    }

    int winCount = rules.quickMode ? 2 : 4;
    bool allFinished = pieces.where((p) => p.type == piece.type).where((p) => p.progress == 56).length >= winCount;
    
    if (allFinished && !winners.contains(piece.type)) {
      winners.add(piece.type);
      if (winners.length == 3) {
        AudioManager().playVictory();
        for (var pType in PlayerType.values) {
          if (!winners.contains(pType)) winners.add(pType);
        }
        status = GameStatus.finished;
        notifyListeners();
        return;
      }
    }

    bool extraTurn = false;
    if (diceValue == 6 || hasWon || caughtSomeone) {
      extraTurn = true;
    } else if (rules.rediceOnOne && diceValue == 1) {
      extraTurn = true;
    }

    if (extraTurn) {
      status = GameStatus.rolling;
      diceValue = 0;
      notifyListeners();
      _checkAndExecuteCpuTurn();
    } else {
      nextTurn();
    }
  }

  bool _checkCollisions(PieceModel movedPiece) {
    if (movedPiece.progress < 0 || movedPiece.progress >= 51) return false;
    
    int movedGlobalIdx = (PathConstants.getStartIdx(movedPiece.type) + movedPiece.progress) % 52;
    if (PathConstants.isSafeGlobalIdx(movedGlobalIdx)) return false;

    bool captured = false;
    for (var other in pieces) {
      if (other.type == movedPiece.type) continue;
      if (other.progress < 0 || other.progress >= 51) continue;

      int otherGlobalIdx = (PathConstants.getStartIdx(other.type) + other.progress) % 52;
      if (otherGlobalIdx == movedGlobalIdx) {
        other.progress = -1;
        captured = true;
      }
    }
    return captured;
  }

  void nextTurn() {
    if (!isMatchActive) return;
    sixCount = 0;
    int currentIdx = PlayerType.values.indexOf(currentPlayer);
    int nextIdx = (currentIdx + 1) % 4;
    currentPlayer = PlayerType.values[nextIdx];
    
    // Skip winners and absent (non-participating) players
    int safety = 0;
    while (safety < 4 &&
        (winners.contains(currentPlayer) ||
            playerModes[currentPlayer] == PlayerMode.absent)) {
      nextIdx = (nextIdx + 1) % 4;
      currentPlayer = PlayerType.values[nextIdx];
      safety++;
    }

    status = GameStatus.rolling;
    diceValue = 0;
    movablePieces = [];
    notifyListeners();
    
    _checkAndExecuteCpuTurn();
  }

  Future<void> _checkAndExecuteCpuTurn() async {
    if (!isMatchActive || status == GameStatus.finished) return;
    
    if (playerModes[currentPlayer] == PlayerMode.ai) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!isMatchActive) return;
      rollDice();
    }
    // PlayerMode.online: remote player handles their own turn
  }
}
