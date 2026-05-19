import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_analog_clock_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_static_image_settings.dart';

void main() {
  test('parse defaults when empty', () {
    expect(
      AnalogClockOverlaySettings.parse(''),
      AnalogClockOverlaySettings.defaults,
    );
  });

  test('parse normalizes dial labels and hand accents', () {
    final s = AnalogClockOverlaySettings.parseMap({
      'dialLabels': 'ROMAN_NUMERALS',
      'hourHandAccent': 2,
      'minuteHandAccent': 'accent3',
      'secondHandAccent': '1',
      'scale': 0.15,
    });
    expect(s.dialLabels, 'roman_numerals');
    expect(s.hourHandAccent, 2);
    expect(s.minuteHandAccent, 'accent3');
    expect(s.secondHandAccent, 'accent1');
    expect(s.placement.scale, 0.15);
  });

  test('parse unknown dialLabels falls back to none', () {
    final s = AnalogClockOverlaySettings.parseMap({
      'dialLabels': 'invalid',
    });
    expect(s.dialLabels, kAnalogClockOverlayDialLabelsDefault);
  });

  test('normalize strips enabled and messages', () {
    final norm = normalizeAnalogClockOverlayConfigJsonString(
      '{"enabled":true,"messages":["x"],"dialLabels":"numbers","x":0.5,"y":0.5}',
    );
    expect(norm, isNotNull);
    final parsed = AnalogClockOverlaySettings.parse(norm!);
    expect(parsed.dialLabels, 'numbers');
    expect(parsed.placement.x, 0.5);
  });

  test('normalize rejects invalid dialLabels', () {
    expect(
      normalizeAnalogClockOverlayConfigJsonString('{"dialLabels": 1}'),
      isNull,
    );
    expect(
      normalizeAnalogClockOverlayConfigJsonString('{"dialLabels": "bogus"}'),
      isNull,
    );
  });
}
