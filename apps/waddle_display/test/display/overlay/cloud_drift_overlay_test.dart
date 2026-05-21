import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/cloud_drift_overlay.dart'
    show CloudDriftOverlay, cloudDriftCloudCount, kCloudDriftCycleDuration;
import 'package:waddle_shared/persistence/display_overlay_cloud_drift_settings.dart'
    show CloudDriftScheduleSettings, kCloudDriftDensityMin, kCloudDriftDensityMax;

void main() {
  test('cloudDriftCloudCount scales with density', () {
    expect(cloudDriftCloudCount(kCloudDriftDensityMin), 4);
    expect(cloudDriftCloudCount(kCloudDriftDensityMax), 28);
    expect(
      cloudDriftCloudCount(0.5),
      greaterThan(cloudDriftCloudCount(kCloudDriftDensityMin)),
    );
  });

  test('kCloudDriftCycleDuration is fixed crossing period', () {
    expect(kCloudDriftCycleDuration, const Duration(seconds: 25));
  });

  testWidgets('CloudDriftOverlay paints cloud drift layer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CloudDriftOverlay(
            settings: CloudDriftScheduleSettings.defaults,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('cloud_drift_custom_paint')),
      findsOneWidget,
    );
  });

  testWidgets('CloudDriftOverlay repaints with parsed settings', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CloudDriftOverlay(
            settings: CloudDriftScheduleSettings.parse(
              '{"cloud_type":"cumulus","scatter":0.8,"density":0.6,'
              '"opacity":0.7,"color":"#B8BFC8"}',
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
      find.byKey(const Key('cloud_drift_custom_paint')),
      findsOneWidget,
    );
  });
}
