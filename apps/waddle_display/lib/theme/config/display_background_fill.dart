import 'package:flutter/material.dart';

/// How [DisplayBackgroundFill] maps to a Flutter [Gradient].
enum DisplayGradientPattern {
  linearDiagonalDown,
  linearVertical,
  linearHorizontal,
  linearDiagonalUp,
  radialCenter,
  sweepCenter,
}

/// Solid fallback plus optional multi-stop gradient for display chrome backgrounds.
@immutable
class DisplayBackgroundFill {
  DisplayBackgroundFill({
    required this.solidColor,
    this.gradientColors = const [],
    this.stops,
    this.pattern = DisplayGradientPattern.linearDiagonalDown,
  }) {
    assert(
      gradientColors.isEmpty || gradientColors.length >= 2,
      'gradientColors needs at least two stops when non-empty',
    );
  }

  final Color solidColor;
  final List<Color> gradientColors;
  final List<double>? stops;
  final DisplayGradientPattern pattern;

  /// First gradient stop, or [solidColor] when no gradient is defined.
  Color resolveColor() =>
      gradientColors.isNotEmpty ? gradientColors.first : solidColor;

  bool get hasGradient => gradientColors.length >= 2;

  Gradient? toGradient() {
    if (!hasGradient) {
      return null;
    }
    return switch (pattern) {
      DisplayGradientPattern.linearDiagonalDown => LinearGradient(
          colors: gradientColors,
          stops: stops,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      DisplayGradientPattern.linearVertical => LinearGradient(
          colors: gradientColors,
          stops: stops,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      DisplayGradientPattern.linearHorizontal => LinearGradient(
          colors: gradientColors,
          stops: stops,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      DisplayGradientPattern.linearDiagonalUp => LinearGradient(
          colors: gradientColors,
          stops: stops,
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
      DisplayGradientPattern.radialCenter => RadialGradient(
          colors: gradientColors,
          stops: stops,
          center: Alignment.center,
          radius: 1.0,
        ),
      DisplayGradientPattern.sweepCenter => SweepGradient(
          colors: gradientColors,
          stops: stops,
          center: Alignment.center,
        ),
    };
  }

  LinearGradient? toLinearGradient() {
    final gradient = toGradient();
    return gradient is LinearGradient ? gradient : null;
  }
}
