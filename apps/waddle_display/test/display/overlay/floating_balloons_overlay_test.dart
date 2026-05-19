import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/balloon_overlay_draw.dart';
import 'package:waddle_display/display/overlay/floating_balloons_overlay.dart';
import 'package:waddle_shared/persistence/display_overlay_floating_balloons_settings.dart';

void main() {
  test('cluster stays visible until bottom clears top edge', () {
    final layouts = floatingBalloonClusterLayoutOffsets(5);
    const sizes = [1.0, 1.0, 1.0, 1.0, 1.0];
    const centerY = 40.0;
    const balloonSize = 90.0;
    final stringDrop =
        balloonClusterStringDropFromLayouts(layouts, balloonSize, sizes);
    final top = balloonClusterTopY(
      clusterCenterY: centerY,
      balloonSize: balloonSize,
      layouts: layouts,
      sizeFactors: sizes,
    );
    final bottom = balloonClusterBottomY(
      clusterCenterY: centerY,
      balloonSize: balloonSize,
      layouts: layouts,
      sizeFactors: sizes,
      stringDrop: stringDrop,
    );
    expect(bottom, greaterThan(top));
    expect(top, lessThan(0));
    expect(bottom, greaterThan(0));
  });

  test('parseBalloonOverlayHexColor accepts 6- and 8-digit hex', () {
    expect(parseBalloonOverlayHexColor('#AABBCC'), isNotNull);
    expect(parseBalloonOverlayHexColor('#11223344'), isNotNull);
    expect(parseBalloonOverlayHexColor('bad'), isNull);
  });

  testWidgets('FloatingBalloonsOverlay paints rising balloons', (tester) async {
    final settings = FloatingBalloonsScheduleSettings(
      colorHexes: const ['#E53935', '#00BCD4', '#FFEB3B'],
      spawnIntervalSec: 1,
      riseSpeed: 120,
      maxActive: 4,
      clusterChance: 0.85,
      balloonScale: 0.12,
      scaleJitter: 0.1,
      opacity: 0.95,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: FloatingBalloonsOverlay(settings: settings),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('floating_balloons_paint')), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('floating_balloons_paint')), findsOneWidget);
  });

  testWidgets('FloatingBalloonsOverlay uses default palette when colors empty',
      (tester) async {
    const settings = FloatingBalloonsScheduleSettings(
      colorHexes: [],
      spawnIntervalSec: 60,
      riseSpeed: 85,
      maxActive: 2,
      clusterChance: 0,
      balloonScale: 0.09,
      scaleJitter: 0,
      opacity: 0.92,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: FloatingBalloonsOverlay(settings: settings),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('floating_balloons_paint')), findsOneWidget);
  });
}
