import 'dart:convert';

import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_edge_glow_settings.dart';

void main() {
  test('normalizeEdgeGlowSettingsJsonString empty object', () {
    expect(normalizeEdgeGlowSettingsJsonString(''), '{}');
    expect(normalizeEdgeGlowSettingsJsonString('  {}  '), '{}');
  });

  test('normalizeEdgeGlowSettingsJsonString preserves valid keys', () {
    final raw = '{"color":"#FF3B30","intensity":0.65,"pulse_speed":1.0}';
    final out = normalizeEdgeGlowSettingsJsonString(raw);
    expect(out, isNotNull);
    expect(jsonDecode(out!), {
      'color': '#FF3B30',
      'intensity': 0.65,
      'pulse_speed': 1.0,
    });
  });

  test('normalizeEdgeGlowSettingsJsonString strips legacy message keys', () {
    final out = normalizeEdgeGlowSettingsJsonString(
      '{"messages":["Hi"],"color":"#AABBCC","intensity":0.5}',
    );
    expect(out, isNotNull);
    expect(jsonDecode(out!), {'color': '#AABBCC', 'intensity': 0.5});
  });

  test('normalize clamps extreme intensity and pulse_speed into range', () {
    final low = normalizeEdgeGlowSettingsJsonString('{"intensity":0.01}');
    expect(jsonDecode(low!), {'intensity': 0.08});
    final hi = normalizeEdgeGlowSettingsJsonString('{"intensity":0.99}');
    expect(jsonDecode(hi!), {'intensity': 0.95});
    final slow = normalizeEdgeGlowSettingsJsonString('{"pulse_speed":0.001}');
    expect(jsonDecode(slow!), {'pulse_speed': 0.05});
    final fast = normalizeEdgeGlowSettingsJsonString('{"pulse_speed":9}');
    expect(jsonDecode(fast!), {'pulse_speed': 3.0});
  });

  test('normalize rejects bad types', () {
    expect(normalizeEdgeGlowSettingsJsonString('{"intensity":"half"}'), isNull);
    expect(normalizeEdgeGlowSettingsJsonString('{"pulse_speed":"slow"}'), isNull);
    expect(normalizeEdgeGlowSettingsJsonString('{"color":123}'), isNull);
    expect(normalizeEdgeGlowSettingsJsonString('{"color":"red"}'), isNull);
  });

  test('normalize rejects non-object', () {
    expect(normalizeEdgeGlowSettingsJsonString('[]'), isNull);
  });

  test('EdgeGlowScheduleSettings.parse defaults', () {
    final s = EdgeGlowScheduleSettings.parse('{}');
    expect(s.colorHex, EdgeGlowScheduleSettings.defaults.colorHex);
    expect(s.intensity, EdgeGlowScheduleSettings.defaults.intensity);
    expect(s.pulseSpeed, EdgeGlowScheduleSettings.defaults.pulseSpeed);
  });

  test('EdgeGlowScheduleSettings.parse reads values', () {
    final s = EdgeGlowScheduleSettings.parse(
      '{"color":"#112233","intensity":0.8,"pulse_speed":2.0}',
    );
    expect(s.colorHex, '#112233');
    expect(s.intensity, 0.8);
    expect(s.pulseSpeed, 2.0);
  });

  test('EdgeGlowScheduleSettings.parse falls back on invalid color', () {
    final s = EdgeGlowScheduleSettings.parse('{"color":"not-a-hex"}');
    expect(s.colorHex, EdgeGlowScheduleSettings.defaults.colorHex);
  });
}
