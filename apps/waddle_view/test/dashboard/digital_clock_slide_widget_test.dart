import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/clock.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/dashboard/digital_clock_slide_widget.dart';

void main() {
  testWidgets('shows 24h time and formatted date from FakeClock', (tester) async {
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
    expect(find.text('14:30:45'), findsOneWidget);
    expect(find.text('Monday, May 4, 2026'), findsOneWidget);
  });
}
