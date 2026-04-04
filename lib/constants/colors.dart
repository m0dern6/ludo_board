import 'package:flutter/material.dart';

class GameColors {
  static const Color background = Color(0xFFFFFDF5); // Bright warm ivory
  static const Color boardStroke = Color(0xFFD4B996); // Polished tan

  // High contrast aesthetic colors
  static const Color red = Color(0xFFEE4242); // Classic Ludo Red
  static const Color green = Color(0xFF2EA65A); // Leaf Green
  static const Color blue = Color(0xFF3886C8); // Cerulean Blue
  static const Color yellow = Color(0xFFF0BB30); // Golden Yellow

  // Brighter variants for cells and home paths (Stronger saturation)
  static const Color redLight = Color(0xFFFFBDBD);
  static const Color greenLight = Color(0xFFB7E4C7);
  static const Color blueLight = Color(0xFFA7C7E7);
  static const Color yellowLight = Color(0xFFFFE169);

  // Darker for pieces/accents
  static const Color redDark = Color(0xFFB92323);
  static const Color greenDark = Color(0xFF1D783E);
  static const Color blueDark = Color(0xFF266496);
  static const Color yellowDark = Color(0xFFB68B1C);

  static const Color diceBG = Colors.white;
  static const Color shadow = Color(0x33000000);
}
