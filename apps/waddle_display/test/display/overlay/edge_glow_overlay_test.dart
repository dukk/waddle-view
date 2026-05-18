import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/edge_glow_overlay.dart'
    show EdgeGlowOverlay, edgeGlowPulseDuration;
import 'package:waddle_shared/persistence/display_overlay_edge_glow_settings.dart'
    show EdgeGlowScheduleSettings, kEdgeGlowPulseSpeedMin;

void main() {
  test('edgeGlowPulseDuration is faster when pulse_speed is high', () {
    expect(edgeGlowPulseDuration(1.0), const Duration(seconds: 3));
    expect(
      edgeGlowPulseDuration(2.0).inMilliseconds,
      lessThan(edgeGlowPulseDuration(1.0).inMilliseconds),
    );
  });

  test('edgeGlowPulseDuration uses shared minimum pulse speed', () {
    expect(
      edgeGlowPulseDuration(kEdgeGlowPulseSpeedMin),
      const Duration(seconds: 60),
    );
    expect(
      edgeGlowPulseDuration(0.001),
      edgeGlowPulseDuration(kEdgeGlowPulseSpeedMin),
    );
  });

  testWidgets('EdgeGlowOverlay paints edge glow layer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EdgeGlowOverlay(
            settings: EdgeGlowScheduleSettings.defaults,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('edge_glow_custom_paint')),
      findsOneWidget,
    );
  });

  testWidgets('EdgeGlowOverlay repaints with parsed settings', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EdgeGlowOverlay(
            settings: EdgeGlowScheduleSettings.parse(
              '{"color":"#FF0000","intensity":0.5,"pulse_speed":2.0}',
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
      find.byKey(const Key('edge_glow_custom_paint')),
      findsOneWidget,
    );
  });
}
