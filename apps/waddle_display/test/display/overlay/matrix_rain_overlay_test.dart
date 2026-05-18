import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/matrix_rain_overlay.dart'
    show MatrixRainOverlay, matrixRainCycleDuration;
import 'package:waddle_shared/persistence/display_overlay_matrix_rain_settings.dart'
    show MatrixRainScheduleSettings, kMatrixRainFallSpeedMin;

void main() {
  test('matrixRainCycleDuration is slower when fallSpeed is low', () {
    expect(matrixRainCycleDuration(1.0), const Duration(seconds: 5));
    expect(
      matrixRainCycleDuration(0.1).inMilliseconds,
      greaterThan(const Duration(seconds: 15).inMilliseconds),
    );
  });

  test('matrixRainCycleDuration uses shared minimum fall speed', () {
    expect(
      matrixRainCycleDuration(kMatrixRainFallSpeedMin),
      const Duration(seconds: 100),
    );
    expect(
      matrixRainCycleDuration(0.001),
      matrixRainCycleDuration(kMatrixRainFallSpeedMin),
    );
  });

  testWidgets('MatrixRainOverlay paints matrix rain layer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatrixRainOverlay(
            settings: MatrixRainScheduleSettings.defaults,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('matrix_rain_custom_paint')),
      findsOneWidget,
    );
  });

  testWidgets('MatrixRainOverlay repaints with parsed settings', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatrixRainOverlay(
            settings: MatrixRainScheduleSettings.parse(
              '{"opacity":0.2,"fall_speed":0.9}',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(
      find.byKey(const Key('matrix_rain_custom_paint')),
      findsOneWidget,
    );
  });
}
