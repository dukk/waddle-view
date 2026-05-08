import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/clock.dart';
import 'package:waddle_display/curator/screen_layout_parse.dart';
import 'package:waddle_display/display/screens/clock/analog_clock_slide_widget.dart';
import 'package:waddle_display/display/screens/clock/clock_hand_angles.dart';
import 'package:waddle_display/theme/theme_palette_extension.dart';

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

  testWidgets('passes configured dial label mode to painter', (tester) async {
    const spec = ParsedWidgetSpec(
      type: 'analog_clock',
      slot: 'main',
      config: {'dialLabels': 'roman'},
    );
    final theme = ThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: AnalogClockSlideWidget(
            spec: spec,
            theme: theme,
            clock: FakeClock(DateTime(2026, 5, 4, 9, 0, 0)),
            dialSize: 200,
          ),
        ),
      ),
    );
    await tester.pump();

    final customPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey<String>('analog_clock_dial')),
    );
    final painter = customPaint.painter! as AnalogClockPainter;
    expect(painter.dialLabelMode, AnalogClockDialLabelMode.roman);
  });

  testWidgets('defaults hands to accent1, accent2, accent3', (tester) async {
    const accent1 = Color(0xFF111111);
    const accent2 = Color(0xFF222222);
    const accent3 = Color(0xFF333333);
    final theme = ThemeData.light().copyWith(
      extensions: <ThemeExtension<dynamic>>[
        const PaletteTertiaryLayers(
          primary: Colors.black,
          iconColor: Colors.white,
          accent1: accent1,
          accent2: accent2,
          accent3: accent3,
          accent4: Color(0xFF444444),
          colorOrder: <Color>[Colors.black],
          tertiaryLayersByColor: <Color, List<Color>>{},
          primaryPairGradient: LinearGradient(colors: <Color>[Colors.black, Colors.white]),
          secondaryPairGradient: LinearGradient(colors: <Color>[Colors.white, Colors.black]),
        ),
      ],
    );
    const spec = ParsedWidgetSpec(
      type: 'analog_clock',
      slot: 'main',
      config: {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: AnalogClockSlideWidget(
            spec: spec,
            theme: theme,
            clock: FakeClock(DateTime(2026, 5, 4, 9, 0, 0)),
            dialSize: 200,
          ),
        ),
      ),
    );
    await tester.pump();

    final customPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey<String>('analog_clock_dial')),
    );
    final painter = customPaint.painter! as AnalogClockPainter;
    expect(painter.handHour, accent1);
    expect(painter.handMinute, accent2);
    expect(painter.handSecond, accent3);
  });

  testWidgets('supports per-hand accent config overrides', (tester) async {
    const accent1 = Color(0xFF111111);
    const accent2 = Color(0xFF222222);
    const accent3 = Color(0xFF333333);
    final theme = ThemeData.light().copyWith(
      extensions: <ThemeExtension<dynamic>>[
        const PaletteTertiaryLayers(
          primary: Colors.black,
          iconColor: Colors.white,
          accent1: accent1,
          accent2: accent2,
          accent3: accent3,
          accent4: Color(0xFF444444),
          colorOrder: <Color>[Colors.black],
          tertiaryLayersByColor: <Color, List<Color>>{},
          primaryPairGradient: LinearGradient(colors: <Color>[Colors.black, Colors.white]),
          secondaryPairGradient: LinearGradient(colors: <Color>[Colors.white, Colors.black]),
        ),
      ],
    );
    const spec = ParsedWidgetSpec(
      type: 'analog_clock',
      slot: 'main',
      config: {
        'hourHandAccent': 'accent3',
        'minuteHandAccent': 1,
        'secondHandAccent': '2',
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: AnalogClockSlideWidget(
            spec: spec,
            theme: theme,
            clock: FakeClock(DateTime(2026, 5, 4, 9, 0, 0)),
            dialSize: 200,
          ),
        ),
      ),
    );
    await tester.pump();

    final customPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey<String>('analog_clock_dial')),
    );
    final painter = customPaint.painter! as AnalogClockPainter;
    expect(painter.handHour, accent3);
    expect(painter.handMinute, accent1);
    expect(painter.handSecond, accent2);
  });

  test('dial label parser supports cardinal numbers mode', () {
    expect(
      AnalogClockDialLabelMode.fromConfigValue('cardinal_numbers'),
      AnalogClockDialLabelMode.cardinalNumbers,
    );
  });

  test('accent choice parser supports accent2 value', () {
    expect(
      AnalogClockAccentChoice.fromConfigValue('accent2'),
      AnalogClockAccentChoice.accent2,
    );
  });

  test('painter shouldRepaint when dial label mode changes', () {
    final base = AnalogClockPainter(
      angles: const ClockHandAngles(hour: 0, minute: 0, second: 0),
      dialColor: Colors.black,
      faceColor: Colors.white,
      handHour: Colors.black,
      handMinute: Colors.black,
      handSecond: Colors.red,
      dialLabelMode: AnalogClockDialLabelMode.none,
    );
    final changed = AnalogClockPainter(
      angles: const ClockHandAngles(hour: 0, minute: 0, second: 0),
      dialColor: Colors.black,
      faceColor: Colors.white,
      handHour: Colors.black,
      handMinute: Colors.black,
      handSecond: Colors.red,
      dialLabelMode: AnalogClockDialLabelMode.numbers,
    );

    expect(changed.shouldRepaint(base), isTrue);
  });
}
