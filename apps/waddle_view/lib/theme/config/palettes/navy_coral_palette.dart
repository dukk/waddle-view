import 'package:flutter/material.dart';

/// 8-color TV palette with 3 accent colors at the tail end.
abstract final class NavyCoralPalette {
  const NavyCoralPalette._();

  // Primary sequence (left to right in the provided palette).
  static const Color inkBlack = Color(0xFF0D1B2A);
  static const Color prussianBlue = Color(0xFF1B263B);
  static const Color duskBlue = Color(0xFF415A77);
  static const Color dustyDenim = Color(0xFF778DA9);
  static const Color alabasterGrey = Color(0xFFE0E1DD);

  // Accent trio (last three palette colors).
  static const Color lobsterPink = Color(0xFFE05C6C);
  static const Color royalGold = Color(0xFFFFE356);
  static const Color lavenderPurple = Color(0xFF966CB3);

  static const Color primary = inkBlack;
  static const Color background = inkBlack;
  static const Color footerBar = prussianBlue;
  static const Color primaryText = alabasterGrey;
  static const Color mutedText = dustyDenim;
  static const Color accent = lobsterPink;

  static const List<Color> orderedPalette = [
    inkBlack,
    prussianBlue,
    duskBlue,
    dustyDenim,
    alabasterGrey,
    lobsterPink,
    royalGold,
    lavenderPurple,
  ];

  static const List<Color> accents = [lobsterPink, royalGold, lavenderPurple];
}
