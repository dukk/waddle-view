import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/clock.dart';
import 'package:waddle_display/display/overlay/analog_clock_overlay.dart';
import 'package:waddle_shared/persistence/display_overlay_analog_clock_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_clock_placement.dart';

void main() {
  testWidgets('AnalogClockOverlay shows dial and date', (tester) async {
    final clock = FakeClock(DateTime(2026, 5, 4, 9, 0, 0));
    const settings = AnalogClockOverlaySettings(
      placement: ClockOverlayPlacement(
        x: 0.5,
        y: 0.1,
        scale: 0.25,
        opacity: 1.0,
      ),
      dialLabels: 'roman',
      hourHandAccent: 'accent1',
      minuteHandAccent: 'accent2',
      secondHandAccent: 'accent3',
    );
    final theme = ThemeData.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: AnalogClockOverlay(
              settingsList: const [settings],
              theme: theme,
              clock: clock,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Monday, May 4, 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('analog_clock_dial')), findsOneWidget);

    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.left, closeTo(400, 0.01));
    expect(positioned.top, closeTo(60, 0.01));
  });
}
