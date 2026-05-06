import 'package:flutter/material.dart';

import '../ticker_marquee_style.dart';
import 'palettes/graphite_amber_palette.dart';
import '../theme_palette_extension.dart';

ThemeData buildGraphiteAmberDisplayTheme() {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: GraphiteAmberPalette.accent,
    brightness: Brightness.dark,
  );
  final colorScheme = baseScheme.copyWith(
    surface: GraphiteAmberPalette.background,
    onSurface: GraphiteAmberPalette.primaryText,
    primary: GraphiteAmberPalette.accent,
    onPrimary: GraphiteAmberPalette.background,
    secondary: GraphiteAmberPalette.accent,
    onSecondary: GraphiteAmberPalette.background,
    surfaceContainerHighest: GraphiteAmberPalette.footerBar,
    onSurfaceVariant: GraphiteAmberPalette.mutedText,
    outline: GraphiteAmberPalette.accent,
    outlineVariant: GraphiteAmberPalette.mutedText,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: GraphiteAmberPalette.background,
    iconTheme: const IconThemeData(color: GraphiteAmberPalette.mutedText),
    extensions: [
      PaletteTertiaryLayers(
        primary: GraphiteAmberPalette.accent,
        iconColor: GraphiteAmberPalette.mutedText,
        accent1: GraphiteAmberPalette.accent,
        accent2: GraphiteAmberPalette.footerBar,
        accent3: GraphiteAmberPalette.primaryText,
        colorOrder: [GraphiteAmberPalette.background, GraphiteAmberPalette.accent],
        tertiaryLayersByColor: {
          GraphiteAmberPalette.background: [
            Color(0xFF4A4A4A),
            Color(0xFF3A3A3A),
            Color(0xFF1F1F1F),
            Color(0xFF141414),
          ],
          GraphiteAmberPalette.accent: [
            Color(0xFFFFD37A),
            Color(0xFFD8A93F),
            Color(0xFF8B6C25),
            Color(0xFF5D4718),
          ],
        },
        primaryPairGradient: LinearGradient(
          colors: [GraphiteAmberPalette.background, Color(0xFF3A3A3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        secondaryPairGradient: LinearGradient(
          colors: [Color(0xFF3A3A3A), GraphiteAmberPalette.footerBar],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ],
  );

  final withText = base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: GraphiteAmberPalette.primaryText,
          displayColor: GraphiteAmberPalette.primaryText,
        )
        .copyWith(
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 20),
        ),
  );
  return applyTickerMarqueeStyle(withText);
}
