import 'package:flutter/material.dart';

import 'ticker_marquee_style.dart';

/// Palette derived from the dark calendar-style reference (navy base, coral accent).
abstract final class DisplayThemeColors {
  const DisplayThemeColors._();

  /// Main canvas behind content.
  static const Color background = Color(0xFF0A0C12);

  /// Bottom bar / ticker strip (slightly lighter navy).
  static const Color footerBar = Color(0xFF2D364E);

  /// Primary labels (month, in-month dates, panel copy).
  static const Color primaryText = Color(0xFFF0F6FC);

  /// Adjacent-month dates and secondary chrome.
  static const Color mutedText = Color(0xFF484F58);

  /// Selection outline and primary emphasis (coral).
  static const Color accent = Color(0xFFE3566A);
}

/// Builds a TV-readable [ThemeData] using [DisplayThemeColors].
class DisplayTheme {
  const DisplayTheme._();

  static ThemeData build() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: DisplayThemeColors.accent,
      brightness: Brightness.dark,
    );
    final colorScheme = baseScheme.copyWith(
      surface: DisplayThemeColors.background,
      onSurface: DisplayThemeColors.primaryText,
      primary: DisplayThemeColors.accent,
      onPrimary: DisplayThemeColors.primaryText,
      secondary: DisplayThemeColors.accent,
      onSecondary: DisplayThemeColors.primaryText,
      surfaceContainerHighest: DisplayThemeColors.footerBar,
      onSurfaceVariant: DisplayThemeColors.mutedText,
      outline: DisplayThemeColors.accent,
      outlineVariant: DisplayThemeColors.mutedText,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: DisplayThemeColors.background,
    );

    final withText = base.copyWith(
      textTheme: base.textTheme
          .apply(
            bodyColor: DisplayThemeColors.primaryText,
            displayColor: DisplayThemeColors.primaryText,
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
}
