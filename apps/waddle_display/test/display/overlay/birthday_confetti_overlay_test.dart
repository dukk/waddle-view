import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/birthday_confetti_overlay.dart'
    show BirthdayConfettiOverlay, birthdayConfettiCycleDuration;
import 'package:waddle_display/theme/theme_palette_extension.dart';
import 'package:waddle_shared/persistence/display_overlay_confetti_settings.dart'
    show BirthdayConfettiScheduleSettings, kBirthdayConfettiFallSpeedMin;

LinearGradient _g(Color a, Color b) => LinearGradient(colors: [a, b]);

const _c1 = Color(0xFF010101);
const _c2 = Color(0xFF020202);
const _c3 = Color(0xFF030303);
const _c4 = Color(0xFF040404);

PaletteTertiaryLayers _samplePalette() {
  return PaletteTertiaryLayers(
    primary: const Color(0xFF111111),
    iconColor: const Color(0xFF222222),
    accent1: const Color(0xFF333333),
    accent2: const Color(0xFF444444),
    accent3: const Color(0xFF555555),
    accent4: const Color(0xFF666666),
    colorOrder: const [Color(0xFF666666)],
    tertiaryLayersByColor: const {},
    primaryPairGradient: _g(_c1, _c2),
    secondaryPairGradient: _g(_c3, _c4),
  );
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 60}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  test('birthdayConfettiCycleDuration is slower when fallSpeed is low', () {
    expect(birthdayConfettiCycleDuration(1.0), const Duration(seconds: 5));
    expect(
      birthdayConfettiCycleDuration(0.14).inMilliseconds,
      greaterThan(const Duration(seconds: 15).inMilliseconds),
    );
  });

  test('birthdayConfettiCycleDuration uses shared minimum fall speed', () {
    expect(
      birthdayConfettiCycleDuration(kBirthdayConfettiFallSpeedMin),
      const Duration(seconds: 250),
    );
    expect(
      birthdayConfettiCycleDuration(0.005),
      birthdayConfettiCycleDuration(kBirthdayConfettiFallSpeedMin),
    );
  });

  testWidgets('BirthdayConfettiOverlay paints confetti layer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: Scaffold(
          body: BirthdayConfettiOverlay(
            settings: BirthdayConfettiScheduleSettings.defaults,
            messages: const <String>[],
            fallbackAccents: const <Color>[Colors.pink, Colors.amber],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('birthday_confetti_custom_paint')),
      findsOneWidget,
    );
  });

  testWidgets('uses palette accents when colors empty and extension present', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          extensions: <ThemeExtension<dynamic>>[_samplePalette()],
        ),
        home: Scaffold(
          body: BirthdayConfettiOverlay(
            settings: BirthdayConfettiScheduleSettings.parse('{}'),
            messages: const <String>[],
            fallbackAccents: const <Color>[Colors.red],
          ),
        ),
      ),
    );
    await tester.pump();
    await _pumpFrames(tester);
    expect(
      find.byKey(const Key('birthday_confetti_custom_paint')),
      findsOneWidget,
    );
  });

  testWidgets('uses custom hex colors from settings', (tester) async {
    final settings = BirthdayConfettiScheduleSettings.parse(
      '{"shapes":["rect","circle","star","streamer"],'
      '"colors":["#FF00AA","#11223344"]}',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        home: Scaffold(
          body: BirthdayConfettiOverlay(
            settings: settings,
            messages: const <String>[],
            fallbackAccents: const <Color>[Colors.grey],
          ),
        ),
      ),
    );
    await tester.pump();
    await _pumpFrames(tester, frames: 80);
    expect(
      find.byKey(const Key('birthday_confetti_custom_paint')),
      findsOneWidget,
    );
  });

  testWidgets('shows occasional message after interval', (tester) async {
    final settings = BirthdayConfettiScheduleSettings.parse(
      '{"message_interval_sec":12}',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BirthdayConfettiOverlay(
            settings: settings,
            messages: const ['Hello overlay'],
            fallbackAccents: const <Color>[Colors.blue],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 13));
    expect(find.text('Hello overlay'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
    await tester.pump();
  });

  testWidgets('replacing overlay disposes timers', (tester) async {
    final settings = BirthdayConfettiScheduleSettings.parse(
      '{"message_interval_sec":12}',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BirthdayConfettiOverlay(
            settings: settings,
            messages: const ['Hi'],
            fallbackAccents: const <Color>[Colors.green],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
    await tester.pump();
  });
}
