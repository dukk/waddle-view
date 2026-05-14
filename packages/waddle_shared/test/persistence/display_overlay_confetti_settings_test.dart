import 'dart:convert';

import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_confetti_settings.dart';

void main() {
  test('normalizeBirthdayConfettiSettingsJsonString empty object', () {
    expect(normalizeBirthdayConfettiSettingsJsonString(''), '{}');
    expect(normalizeBirthdayConfettiSettingsJsonString('  {}  '), '{}');
  });

  test('normalizeBirthdayConfettiSettingsJsonString preserves valid keys', () {
    final raw =
        '{"shapes":["rect","mix"],"colors":["#FF00AA"],"density":0.4,'
        '"message_interval_sec":40,"fall_speed":0.5,"opacity":0.55}';
    final out = normalizeBirthdayConfettiSettingsJsonString(raw);
    expect(out, isNotNull);
    expect(jsonDecode(out!), {
      'shapes': ['rect', 'mix'],
      'colors': ['#FF00AA'],
      'density': 0.4,
      'message_interval_sec': 40,
      'fall_speed': 0.5,
      'opacity': 0.55,
    });
  });

  test('normalize clamps extreme fall_speed into range', () {
    final out = normalizeBirthdayConfettiSettingsJsonString('{"fall_speed":0.001}');
    expect(out, isNotNull);
    expect(jsonDecode(out!), {'fall_speed': 0.02});
    final hi = normalizeBirthdayConfettiSettingsJsonString('{"fall_speed":9}');
    expect(jsonDecode(hi!), {'fall_speed': 1.8});
  });

  test('normalize rejects bad fall_speed or opacity types', () {
    expect(normalizeBirthdayConfettiSettingsJsonString('{"fall_speed":"slow"}'), isNull);
    expect(normalizeBirthdayConfettiSettingsJsonString('{"opacity":"half"}'), isNull);
  });

  test('normalize rejects non-object and invalid shapes', () {
    expect(normalizeBirthdayConfettiSettingsJsonString('[]'), isNull);
    expect(normalizeBirthdayConfettiSettingsJsonString('{"shapes":"rect"}'), isNull);
    expect(normalizeBirthdayConfettiSettingsJsonString('{"shapes":["bogus"]}'), isNull);
    expect(normalizeBirthdayConfettiSettingsJsonString('{"colors":["not-a-color"]}'), isNull);
  });

  test('BirthdayConfettiScheduleSettings.parse defaults', () {
    final s = BirthdayConfettiScheduleSettings.parse('{}');
    expect(s.shapeTokens, BirthdayConfettiScheduleSettings.defaults.shapeTokens);
    expect(s.colorHexes, isEmpty);
    expect(s.density, BirthdayConfettiScheduleSettings.defaults.density);
    expect(s.messageIntervalSec, BirthdayConfettiScheduleSettings.defaults.messageIntervalSec);
    expect(s.fallSpeed, BirthdayConfettiScheduleSettings.defaults.fallSpeed);
    expect(s.opacity, BirthdayConfettiScheduleSettings.defaults.opacity);
  });

  test('BirthdayConfettiScheduleSettings.parse honors settings', () {
    final s = BirthdayConfettiScheduleSettings.parse(
      '{"shapes":["star","streamer"],"colors":["#112233","#AABBCCDD"],'
      '"density":0.6,"message_interval_sec":50,"fall_speed":0.9,"opacity":0.6}',
    );
    expect(s.shapeTokens, ['star', 'streamer']);
    expect(s.colorHexes, ['#112233', '#AABBCCDD']);
    expect(s.density, 0.6);
    expect(s.messageIntervalSec, 50);
    expect(s.fallSpeed, 0.9);
    expect(s.opacity, 0.6);
  });
}
