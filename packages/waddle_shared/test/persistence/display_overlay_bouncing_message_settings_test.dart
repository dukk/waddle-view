import 'dart:convert';

import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_bouncing_message_settings.dart';

void main() {
  test('normalizeBouncingMessageConfigJsonString empty object', () {
    expect(normalizeBouncingMessageConfigJsonString(''), '{}');
    expect(normalizeBouncingMessageConfigJsonString('  {}  '), '{}');
  });

  test('normalize preserves valid keys', () {
    final raw =
        '{"color":"#FF00AA","font_family":"Roboto","font_size":22,'
        '"font_weight":600,"letter_spacing":1.2,"shadow":false,"speed":0.5}';
    final out = normalizeBouncingMessageConfigJsonString(raw);
    expect(out, isNotNull);
    final m = jsonDecode(out!) as Map<String, dynamic>;
    expect(m['color'], '#FF00AA');
    expect(m['font_family'], 'Roboto');
    expect(m['font_size'], 22);
    expect(m['font_weight'], 600);
    expect(m['letter_spacing'], 1.2);
    expect(m['shadow'], false);
    expect(m['speed'], 0.5);
  });

  test('normalize preserves messages with other keys', () {
    final out = normalizeBouncingMessageConfigJsonString(
      '{"messages":["Hi"],"font_size":22,"speed":0.5}',
    );
    expect(out, isNotNull);
    final m = jsonDecode(out!) as Map<String, dynamic>;
    expect(m['messages'], ['Hi']);
    expect(m['font_size'], 22);
    expect(m['speed'], 0.5);
  });

  test('normalize rejects unknown keys', () {
    expect(
      normalizeBouncingMessageConfigJsonString('{"font_size":20,"extra":1}'),
      isNull,
    );
  });

  test('BouncingMessageScheduleSettings.parse defaults', () {
    final s = BouncingMessageScheduleSettings.parse('{}');
    expect(s.fontSize, BouncingMessageScheduleSettings.defaults.fontSize);
    expect(s.shadow, BouncingMessageScheduleSettings.defaults.shadow);
    expect(s.speed, BouncingMessageScheduleSettings.defaults.speed);
  });
}
