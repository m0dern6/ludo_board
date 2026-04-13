
enum PlayerType { red, green, yellow, blue }

enum PlayerMode { human, ai, online, absent }

enum BoardTheme { classic, royal }

class PieceModel {
  final int id;
  final PlayerType type;
  int progress; // -1 (base), 0..50 (path), 51..55 (home path), 56 (win)
  bool isSafe;

  PieceModel({required this.id, required this.type, this.progress = -1, this.isSafe = false});
}

enum GameStatus { rolling, moving, selecting, finished, paused }

class GameRules {
  bool rediceOnOne;
  bool mustKillToEnterHome;
  bool quickMode; // e.g., only 2 pieces to win
  bool fillWithAi; // fill empty slots with AI players on start
  bool triplesSixLosesTurn; // rolling 3 consecutive 6s causes turn loss
  bool sixAlwaysRerolls; // rolling 6 always grants extra roll, even with no movable pieces

  GameRules({
    this.rediceOnOne = false,
    this.mustKillToEnterHome = false,
    this.quickMode = false,
    this.fillWithAi = true,
    this.triplesSixLosesTurn = false,
    this.sixAlwaysRerolls = false,
  });

  Map<String, dynamic> toJson() => {
    'rediceOnOne': rediceOnOne,
    'mustKillToEnterHome': mustKillToEnterHome,
    'quickMode': quickMode,
    'fillWithAi': fillWithAi,
    'triplesSixLosesTurn': triplesSixLosesTurn,
    'sixAlwaysRerolls': sixAlwaysRerolls,
  };

  factory GameRules.fromJson(Map<String, dynamic> json) => GameRules(
    rediceOnOne: json['rediceOnOne'] ?? false,
    mustKillToEnterHome: json['mustKillToEnterHome'] ?? false,
    quickMode: json['quickMode'] ?? false,
    fillWithAi: json['fillWithAi'] ?? true,
    triplesSixLosesTurn: json['triplesSixLosesTurn'] ?? false,
    sixAlwaysRerolls: json['sixAlwaysRerolls'] ?? false,
  );
}
