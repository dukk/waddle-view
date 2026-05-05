import 'package:flutter/material.dart';

import '../ticker_marquee_style.dart';
import 'palettes/navy_coral_palette.dart';

ThemeData buildNavyCoralDisplayTheme() {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: NavyCoralPalette.accent,
    brightness: Brightness.dark,
  );
  final colorScheme = baseScheme.copyWith(
    surface: NavyCoralPalette.background,
    onSurface: NavyCoralPalette.primaryText,
    primary: NavyCoralPalette.accent,
    onPrimary: NavyCoralPalette.primaryText,
    secondary: NavyCoralPalette.accent,
    onSecondary: NavyCoralPalette.primaryText,
    surfaceContainerHighest: NavyCoralPalette.footerBar,
    onSurfaceVariant: NavyCoralPalette.mutedText,
    outline: NavyCoralPalette.accent,
    outlineVariant: NavyCoralPalette.mutedText,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: NavyCoralPalette.background,
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
