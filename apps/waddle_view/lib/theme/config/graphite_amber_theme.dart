import 'package:flutter/material.dart';

import '../ticker_marquee_style.dart';
import 'palettes/graphite_amber_palette.dart';

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
