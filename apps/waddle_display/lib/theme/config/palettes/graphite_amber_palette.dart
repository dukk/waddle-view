import 'package:flutter/material.dart';

import '../display_background_fill.dart';

/// Charcoal base + amber accent (high-contrast alternate).
abstract final class GraphiteAmberPalette {
  const GraphiteAmberPalette._();

  static const Color background = Color(0xFF121214);
  static const Color footerBar = Color(0xFF2A2A2E);
  static const Color midSurface = Color(0xFF3A3A3A);
  static const Color mutedText = Color(0xFF78716C);
  static const Color primaryText = Color(0xFFF5F5F4);
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentWarm = Color(0xFFFFD37A);
  static const Color accentDeep = Color(0xFFD8A93F);
  static const Color accentShadow = Color(0xFF8B6C25);

  static const Color primaryContainerBackground = Color(0xFF2A2A2E);
  static const Color primaryContainerForeground = primaryText;
  static const Color secondaryContainerBackground = midSurface;
  static const Color secondaryContainerForeground = primaryText;

  static final DisplayBackgroundFill displayBackgroundFill = DisplayBackgroundFill(
    solidColor: background,
    gradientColors: [background, midSurface],
  );

  static final DisplayBackgroundFill primaryContainerFill = DisplayBackgroundFill(
    solidColor: primaryContainerBackground,
    gradientColors: [background, midSurface],
  );

  static final DisplayBackgroundFill secondaryContainerFill = DisplayBackgroundFill(
    solidColor: secondaryContainerBackground,
    gradientColors: [midSurface, footerBar, accent],
  );

  static const List<Color> accents = [
    accent,
    accentWarm,
    accentDeep,
    accentShadow,
  ];

  static const List<Color> neutrals = [
    background,
    footerBar,
    midSurface,
    mutedText,
    primaryText,
  ];
}
