import 'package:flutter/material.dart';

import '../ticker_marquee_style.dart';
import 'palettes/navy_coral_palette.dart';
import '../theme_palette_extension.dart';

ThemeData buildNavyCoralDisplayTheme() {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: NavyCoralPalette.primary,
    brightness: Brightness.dark,
  );
  final colorScheme = baseScheme.copyWith(
    surface: NavyCoralPalette.background,
    onSurface: NavyCoralPalette.primaryText,
    primary: NavyCoralPalette.primary,
    onPrimary: NavyCoralPalette.primaryText,
    secondary: NavyCoralPalette.accents[0],
    onSecondary: NavyCoralPalette.inkBlack,
    tertiary: NavyCoralPalette.accents[1],
    onTertiary: NavyCoralPalette.primaryText,
    tertiaryContainer: NavyCoralPalette.accents[3],
    onTertiaryContainer: NavyCoralPalette.primaryText,
    surfaceContainerHighest: NavyCoralPalette.footerBar,
    onSurfaceVariant: NavyCoralPalette.mutedText,
    outline: NavyCoralPalette.accents[2],
    outlineVariant: NavyCoralPalette.mutedText,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: NavyCoralPalette.background,
    iconTheme: const IconThemeData(color: NavyCoralPalette.dustyDenim),
    extensions: [
      PaletteTertiaryLayers(
        primary: NavyCoralPalette.primary,
        iconColor: NavyCoralPalette.dustyDenim,
        accent1: NavyCoralPalette.accents[0],
        accent2: NavyCoralPalette.accents[1],
        accent3: NavyCoralPalette.accents[2],
        accent4: NavyCoralPalette.accents[3],
        colorOrder: NavyCoralPalette.orderedPalette,
        tertiaryLayersByColor: {
          for (final color in NavyCoralPalette.orderedPalette)
            color: _tertiaryLayersFor(color),
        },
        primaryPairGradient: const LinearGradient(
          colors: [NavyCoralPalette.inkBlack, NavyCoralPalette.prussianBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        secondaryPairGradient: const LinearGradient(
          colors: [NavyCoralPalette.duskBlue, NavyCoralPalette.dustyDenim],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ],
  );

  final withText = base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: NavyCoralPalette.primaryText,
          displayColor: NavyCoralPalette.primaryText,
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

List<Color> _tertiaryLayersFor(Color base) {
  return [
    Color.alphaBlend(Colors.white.withValues(alpha: 0.18), base),
    Color.alphaBlend(Colors.white.withValues(alpha: 0.10), base),
    Color.alphaBlend(Colors.black.withValues(alpha: 0.10), base),
    Color.alphaBlend(Colors.black.withValues(alpha: 0.22), base),
  ];
}
