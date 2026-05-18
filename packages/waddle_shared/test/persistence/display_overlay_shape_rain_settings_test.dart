import 'dart:convert';

import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_shape_rain_settings.dart';

void main() {
  test('normalizeShapeRainSettingsJsonString preserves shapes', () {
    final out = normalizeShapeRainSettingsJsonString(
      '{"shapes":["heart","mix","cat"],"messages":["x"]}',
    );
    expect(out, isNotNull);
    expect(jsonDecode(out!), {
      'shapes': ['heart', 'mix', 'cat'],
    });
  });

  test('normalizeShapeRainSettingsJsonString rejects invalid shapes', () {
    expect(normalizeShapeRainSettingsJsonString('{"shapes":["unicorn"]}'), isNull);
  });

  test('ShapeRainScheduleSettings.parse defaults', () {
    final s = ShapeRainScheduleSettings.parse('{}');
    expect(s.shapeTokens, ShapeRainScheduleSettings.defaults.shapeTokens);
  });
}
