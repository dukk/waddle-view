import 'dart:convert';

import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_matrix_rain_settings.dart';

void main() {
  test('normalizeMatrixRainSettingsJsonString empty object', () {
    expect(normalizeMatrixRainSettingsJsonString(''), '{}');
    expect(normalizeMatrixRainSettingsJsonString('  {}  '), '{}');
  });

  test('normalizeMatrixRainSettingsJsonString preserves valid keys', () {
    final raw = '{"opacity":0.5,"fall_speed":0.8}';
    final out = normalizeMatrixRainSettingsJsonString(raw);
    expect(out, isNotNull);
    expect(jsonDecode(out!), {'opacity': 0.5, 'fall_speed': 0.8});
  });

  test('normalizeMatrixRainSettingsJsonString strips legacy message keys', () {
    final out = normalizeMatrixRainSettingsJsonString(
      '{"messages":["Hi"],"message_interval_sec":40,"opacity":0.4}',
    );
    expect(out, isNotNull);
    expect(jsonDecode(out!), {'opacity': 0.4});
  });

  test('normalize clamps extreme opacity and fall_speed into range', () {
    final low = normalizeMatrixRainSettingsJsonString('{"opacity":0.01}');
    expect(jsonDecode(low!), {'opacity': 0.08});
    final hi = normalizeMatrixRainSettingsJsonString('{"opacity":0.99}');
    expect(jsonDecode(hi!), {'opacity': 0.85});
    final slow = normalizeMatrixRainSettingsJsonString('{"fall_speed":0.001}');
    expect(jsonDecode(slow!), {'fall_speed': 0.05});
    final fast = normalizeMatrixRainSettingsJsonString('{"fall_speed":9}');
    expect(jsonDecode(fast!), {'fall_speed': 2.0});
  });

  test('normalize rejects bad opacity or fall_speed types', () {
    expect(normalizeMatrixRainSettingsJsonString('{"opacity":"half"}'), isNull);
    expect(normalizeMatrixRainSettingsJsonString('{"fall_speed":"slow"}'), isNull);
  });

  test('normalize rejects non-object', () {
    expect(normalizeMatrixRainSettingsJsonString('[]'), isNull);
  });

  test('MatrixRainScheduleSettings.parse defaults', () {
    final s = MatrixRainScheduleSettings.parse('{}');
    expect(s.opacity, MatrixRainScheduleSettings.defaults.opacity);
    expect(s.fallSpeed, MatrixRainScheduleSettings.defaults.fallSpeed);
  });

  test('MatrixRainScheduleSettings.parse reads values', () {
    final s = MatrixRainScheduleSettings.parse(
      '{"opacity":0.6,"fall_speed":1.1}',
    );
    expect(s.opacity, 0.6);
    expect(s.fallSpeed, 1.1);
  });
}
