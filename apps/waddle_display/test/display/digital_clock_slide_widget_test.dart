import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/clock.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/display/screens/clock/digital_clock_slide_widget.dart';

void main() {
  testWidgets('default: 12h with AM/PM, no seconds, and formatted date', (tester) async {
    final clock = FakeClock(DateTime(2026, 5, 4, 14, 30, 45));
    const spec = ParsedWidgetSpec(
      type: 'digital_clock',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: DigitalClockSlideWidget(
            spec: spec,
            theme: theme,
            clock: clock,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('2:30 PM'), findsOneWidget);
    expect(find.text('Monday, May 4, 2026'), findsOneWidget);
  });

  testWidgets('hour24 and showSeconds restore prior signage format', (tester) async {
    final clock = FakeClock(DateTime(2026, 5, 4, 14, 30, 45));
    const spec = ParsedWidgetSpec(
      type: 'digital_clock',
      slot: 'main',
      config: {
        'hour24': true,
        'showSeconds': true,
      },
    );
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: DigitalClockSlideWidget(
            spec: spec,
            theme: theme,
            clock: clock,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('14:30:45'), findsOneWidget);
  });

  testWidgets('hour24 without seconds omits trailing segment', (tester) async {
    final clock = FakeClock(DateTime(2026, 5, 4, 9, 5, 7));
    const spec = ParsedWidgetSpec(
      type: 'digital_clock',
      slot: 'main',
      config: {'hour24': true},
    );
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: DigitalClockSlideWidget(
            spec: spec,
            theme: theme,
            clock: clock,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('09:05'), findsOneWidget);
  });
}
