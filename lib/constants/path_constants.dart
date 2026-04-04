import 'package:flutter/material.dart';
import '../models/piece_model.dart';

class PathConstants {
  // All 52 cells of the circular path.
  // We'll index them 0..51.
  // Using Offset(column, row) to map dx -> left, dy -> top
  static final List<Offset> fullPath = [
    Offset(0, 6), Offset(1, 6), Offset(2, 6), Offset(3, 6), Offset(4, 6), Offset(5, 6),
    Offset(6, 5), Offset(6, 4), Offset(6, 3), Offset(6, 2), Offset(6, 1), Offset(6, 0),
    Offset(7, 0),
    Offset(8, 0), Offset(8, 1), Offset(8, 2), Offset(8, 3), Offset(8, 4), Offset(8, 5),
    Offset(9, 6), Offset(10, 6), Offset(11, 6), Offset(12, 6), Offset(13, 6), Offset(14, 6),
    Offset(14, 7),
    Offset(14, 8), Offset(13, 8), Offset(12, 8), Offset(11, 8), Offset(10, 8), Offset(9, 8),
    Offset(8, 9), Offset(8, 10), Offset(8, 11), Offset(8, 12), Offset(8, 13), Offset(8, 14),
    Offset(7, 14),
    Offset(6, 14), Offset(6, 13), Offset(6, 12), Offset(6, 11), Offset(6, 10), Offset(6, 9),
    Offset(5, 8), Offset(4, 8), Offset(3, 8), Offset(2, 8), Offset(1, 8), Offset(0, 8),
    Offset(0, 7),
  ];

  static const int redStartPathIdx = 1;
  static const int greenStartPathIdx = 14;
  static const int yellowStartPathIdx = 27;
  static const int blueStartPathIdx = 40;

  // Home paths (column, row)
  static final List<Offset> redHomePath = [
    Offset(1, 7), Offset(2, 7), Offset(3, 7), Offset(4, 7), Offset(5, 7), Offset(6, 7)
  ];
  static final List<Offset> greenHomePath = [
    Offset(7, 1), Offset(7, 2), Offset(7, 3), Offset(7, 4), Offset(7, 5), Offset(7, 6)
  ];
  static final List<Offset> yellowHomePath = [
    Offset(13, 7), Offset(12, 7), Offset(11, 7), Offset(10, 7), Offset(9, 7), Offset(8, 7)
  ];
  static final List<Offset> blueHomePath = [
    Offset(7, 13), Offset(7, 12), Offset(7, 11), Offset(7, 10), Offset(7, 9), Offset(7, 8)
  ];

  static const List<int> safePositions = [1, 9, 14, 22, 27, 35, 40, 48];
  static bool isSafeGlobalIdx(int idx) => safePositions.contains(idx);

  // Base positions (column, row)
  static final List<Offset> redBasePositions = [Offset(1.5, 1.5), Offset(3.5, 1.5), Offset(1.5, 3.5), Offset(3.5, 3.5)];
  static final List<Offset> greenBasePositions = [Offset(10.5, 1.5), Offset(12.5, 1.5), Offset(10.5, 3.5), Offset(12.5, 3.5)];
  static final List<Offset> yellowBasePositions = [Offset(10.5, 10.5), Offset(12.5, 10.5), Offset(10.5, 12.5), Offset(12.5, 12.5)];
  static final List<Offset> blueBasePositions = [Offset(1.5, 10.5), Offset(3.5, 10.5), Offset(1.5, 12.5), Offset(3.5, 12.5)];

  static List<Offset> getBasePositions(PlayerType type) {
    switch (type) {
      case PlayerType.red: return redBasePositions;
      case PlayerType.green: return greenBasePositions;
      case PlayerType.yellow: return yellowBasePositions;
      case PlayerType.blue: return blueBasePositions;
    }
  }

  static List<Offset> getHomePath(PlayerType type) {
    switch (type) {
      case PlayerType.red: return redHomePath;
      case PlayerType.green: return greenHomePath;
      case PlayerType.yellow: return yellowHomePath;
      case PlayerType.blue: return blueHomePath;
    }
  }

  static int getStartIdx(PlayerType type) {
    switch (type) {
      case PlayerType.red: return redStartPathIdx;
      case PlayerType.green: return greenStartPathIdx;
      case PlayerType.yellow: return yellowStartPathIdx;
      case PlayerType.blue: return blueStartPathIdx;
    }
  }
}
