import 'package:flutter/material.dart';

/// Builds a high-contrast TV-friendly [ThemeData].
class TvTheme {
  const TvTheme._();

  static ThemeData build({Color seed = const Color(0xFF0D47A1)}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ).copyWith(
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
  }
}
