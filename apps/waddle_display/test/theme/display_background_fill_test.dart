import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/theme/config/display_background_fill.dart';

void main() {
  const red = Color(0xFFFF0000);
  const blue = Color(0xFF0000FF);
  const green = Color(0xFF00FF00);

  test('resolveColor returns solid when no gradient', () {
    final fill = DisplayBackgroundFill(solidColor: red);
    expect(fill.resolveColor(), red);
    expect(fill.toGradient(), isNull);
  });

  test('resolveColor returns first gradient stop when gradient present', () {
    final fill = DisplayBackgroundFill(
      solidColor: red,
      gradientColors: [blue, green],
    );
    expect(fill.resolveColor(), blue);
    expect(fill.hasGradient, isTrue);
  });

  test('linearDiagonalDown maps to topLeft bottomRight', () {
    final fill = DisplayBackgroundFill(
      solidColor: red,
      gradientColors: [blue, green],
      pattern: DisplayGradientPattern.linearDiagonalDown,
    );
    final gradient = fill.toLinearGradient()!;
    expect(gradient.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);
    expect(gradient.colors, [blue, green]);
  });

  test('linearVertical maps to top bottom', () {
    final fill = DisplayBackgroundFill(
      solidColor: red,
      gradientColors: [blue, green],
      pattern: DisplayGradientPattern.linearVertical,
    );
    final gradient = fill.toLinearGradient()!;
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
  });

  test('radialCenter produces RadialGradient', () {
    final fill = DisplayBackgroundFill(
      solidColor: red,
      gradientColors: [blue, green],
      pattern: DisplayGradientPattern.radialCenter,
    );
    expect(fill.toGradient(), isA<RadialGradient>());
    expect(fill.toLinearGradient(), isNull);
  });

  test('sweepCenter produces SweepGradient', () {
    final fill = DisplayBackgroundFill(
      solidColor: red,
      gradientColors: [blue, green],
      pattern: DisplayGradientPattern.sweepCenter,
    );
    expect(fill.toGradient(), isA<SweepGradient>());
  });

  test('stops are forwarded to gradient', () {
    final fill = DisplayBackgroundFill(
      solidColor: red,
      gradientColors: [blue, green, red],
      stops: [0.0, 0.5, 1.0],
    );
    expect(fill.toLinearGradient()!.stops, [0.0, 0.5, 1.0]);
  });
}
