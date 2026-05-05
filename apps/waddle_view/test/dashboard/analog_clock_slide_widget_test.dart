import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/clock.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/dashboard/analog_clock_slide_widget.dart';

void main() {
  testWidgets('shows date and CustomPaint dial', (tester) async {
    final clock = FakeClock(DateTime(2026, 5, 4, 9, 0, 0));
    const spec = ParsedWidgetSpec(
      type: 'analog_clock',
      slot: 'main',
      config: {},
    );
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: AnalogClockSlideWidget(
            spec: spec,
            theme: theme,
            clock: clock,
            dialSize: 200,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Monday, May 4, 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('analog_clock_dial')), findsOneWidget);
  });
}
