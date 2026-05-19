import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/clock.dart';
import 'package:waddle_display/display/overlay/digital_clock_overlay.dart';
import 'package:waddle_shared/persistence/display_overlay_clock_placement.dart';
import 'package:waddle_shared/persistence/display_overlay_digital_clock_settings.dart';

void main() {
  testWidgets('DigitalClockOverlay shows time at configured position', (tester) async {
    final clock = FakeClock(DateTime(2026, 5, 4, 14, 30, 45));
    const settings = DigitalClockOverlaySettings(
      placement: ClockOverlayPlacement(
        x: 0.1,
        y: 0.2,
        scale: 0.4,
        opacity: 1.0,
      ),
      hour24: false,
      showSeconds: false,
    );
    final theme = ThemeData.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: DigitalClockOverlay(
              settingsList: const [settings],
              theme: theme,
              clock: clock,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2:30 PM'), findsOneWidget);
    expect(find.text('Monday, May 4, 2026'), findsOneWidget);

    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.left, closeTo(80, 0.01));
    expect(positioned.top, closeTo(120, 0.01));
  });

  testWidgets('DigitalClockOverlay hour24 and showSeconds', (tester) async {
    final clock = FakeClock(DateTime(2026, 5, 4, 14, 30, 45));
    const settings = DigitalClockOverlaySettings(
      placement: ClockOverlayPlacement.defaults,
      hour24: true,
      showSeconds: true,
    );
    final theme = ThemeData.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: DigitalClockOverlay(
            settingsList: const [settings],
            theme: theme,
            clock: clock,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('14:30:45'), findsOneWidget);
  });
}
