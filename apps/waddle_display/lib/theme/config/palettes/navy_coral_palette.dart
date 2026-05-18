import 'package:flutter/material.dart';

import '../display_background_fill.dart';

/// 9-color TV palette: five base neutrals plus four accent colors at the tail.
abstract final class NavyCoralPalette {
  const NavyCoralPalette._();

  static const Color inkBlack = Color(0xFF0D1B2A);
  static const Color prussianBlue = Color(0xFF1B263B);
  static const Color duskBlue = Color(0xFF415A77);
  static const Color dustyDenim = Color(0xFF778DA9);
  static const Color alabasterGrey = Color(0xFFE0E1DD);

  static const Color mutedTeal = Color(0xFF83AF84);
  static const Color lobsterPink = Color(0xFFE05C6C);
  static const Color royalGold = Color(0xFFFFE356);
  static const Color lavenderPurple = Color(0xFF966CB3);

  static const Color primary = inkBlack;
  static const Color background = inkBlack;
  static const Color footerBar = prussianBlue;
  static const Color primaryText = alabasterGrey;
  static const Color mutedText = dustyDenim;
  static const Color accent = lobsterPink;

  static const Color primaryContainerBackground = prussianBlue;
  static const Color primaryContainerForeground = alabasterGrey;
  static const Color secondaryContainerBackground = duskBlue;
  static const Color secondaryContainerForeground = alabasterGrey;

  static final DisplayBackgroundFill displayBackgroundFill = DisplayBackgroundFill(
    solidColor: inkBlack,
    gradientColors: [inkBlack, prussianBlue, duskBlue],
  );

  static final DisplayBackgroundFill primaryContainerFill = DisplayBackgroundFill(
    solidColor: prussianBlue,
    gradientColors: [prussianBlue, duskBlue],
  );

  static final DisplayBackgroundFill secondaryContainerFill = DisplayBackgroundFill(
    solidColor: duskBlue,
    gradientColors: [duskBlue, dustyDenim, mutedTeal],
  );

  static const List<Color> orderedPalette = [
    inkBlack,
    prussianBlue,
    duskBlue,
    dustyDenim,
    alabasterGrey,
    mutedTeal,
    lobsterPink,
    royalGold,
    lavenderPurple,
  ];

  static const List<Color> accents = [
    mutedTeal,
    lobsterPink,
    royalGold,
    lavenderPurple,
  ];
}
