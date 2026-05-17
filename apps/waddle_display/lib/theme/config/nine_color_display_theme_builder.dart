import 'package:flutter/material.dart';

import '../ticker_marquee_style.dart';
import '../theme_palette_extension.dart';
import 'nine_color_tv_palette.dart';

ThemeData buildNineColorDisplayTheme(NineColorTvPalette palette) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: Brightness.dark,
  );
  final colorScheme = baseScheme.copyWith(
    surface: palette.background,
    onSurface: palette.primaryText,
    primary: palette.primary,
    onPrimary: palette.primaryText,
    secondary: palette.accents[0],
    onSecondary: palette.background,
    tertiary: palette.accents[1],
    onTertiary: palette.primaryText,
    tertiaryContainer: palette.accents[3],
    onTertiaryContainer: palette.primaryText,
    surfaceContainerHighest: palette.footerBar,
    onSurfaceVariant: palette.mutedText,
    outline: palette.accents[2],
    outlineVariant: palette.mutedText,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.background,
    iconTheme: IconThemeData(color: palette.iconColor),
    extensions: [
      PaletteTertiaryLayers(
        primary: palette.primary,
        iconColor: palette.iconColor,
        accent1: palette.accents[0],
        accent2: palette.accents[1],
        accent3: palette.accents[2],
        accent4: palette.accents[3],
        colorOrder: palette.orderedPalette,
        tertiaryLayersByColor: {
          for (final color in palette.orderedPalette)
            color: _tertiaryLayersFor(color),
        },
        primaryPairGradient: palette.primaryPairGradient,
        secondaryPairGradient: palette.secondaryPairGradient,
      ),
    ],
  );

  final withText = base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: palette.primaryText,
          displayColor: palette.primaryText,
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
