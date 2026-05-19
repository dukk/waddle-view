import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/birthday_confetti_overlay.dart'
    show BirthdayConfettiOverlay, birthdayConfettiCycleDuration;
import 'package:waddle_shared/persistence/display_overlay_confetti_settings.dart'
    show
        BirthdayConfettiScheduleSettings,
        kBirthdayConfettiDefaultColorHexes,
        kBirthdayConfettiFallSpeedMin;

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

  testWidgets('uses stock festive palette when colors empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: Scaffold(
          body: BirthdayConfettiOverlay(
            settings: BirthdayConfettiScheduleSettings.parse('{}'),
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
    expect(kBirthdayConfettiDefaultColorHexes, hasLength(4));
  });

  testWidgets('uses custom hex colors from settings', (tester) async {
    final settings = BirthdayConfettiScheduleSettings.parse(
      '{"colors":["#FF00AA","#11223344"]}',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        home: Scaffold(
          body: BirthdayConfettiOverlay(
            settings: settings,
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
}
