import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_clock_placement.dart';
import 'package:waddle_shared/persistence/display_overlay_digital_clock_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_static_image_settings.dart';

void main() {
  test('parse defaults when empty', () {
    expect(
      DigitalClockOverlaySettings.parse(''),
      DigitalClockOverlaySettings.defaults,
    );
    expect(
      DigitalClockOverlaySettings.parse('{}'),
      DigitalClockOverlaySettings.defaults,
    );
  });

  test('parse clamps placement and reads clock flags', () {
    final s = DigitalClockOverlaySettings.parseMap({
      'x': 2.0,
      'y': -1.0,
      'scale': 99.0,
      'opacity': 1.5,
      'hour24': true,
      'showSeconds': true,
    });
    expect(s.placement.x, 1.0);
    expect(s.placement.y, 0.0);
    expect(s.placement.scale, kStaticImageOverlayScaleMax);
    expect(s.placement.opacity, 1.0);
    expect(s.hour24, isTrue);
    expect(s.showSeconds, isTrue);
    expect(s.clockConfigMap(), {'hour24': true, 'showSeconds': true});
  });

  test('normalize strips enabled and messages', () {
    final norm = normalizeDigitalClockOverlayConfigJsonString(
      '{"enabled":true,"messages":["x"],"hour24":true,"showSeconds":true,'
      '"x":0.1,"y":0.2,"scale":0.25,"opacity":0.5}',
    );
    expect(norm, isNotNull);
    final parsed = DigitalClockOverlaySettings.parse(norm!);
    expect(parsed.hour24, isTrue);
    expect(parsed.showSeconds, isTrue);
    expect(parsed.placement.opacity, 0.5);
  });

  test('normalize rejects invalid hour24 type', () {
    expect(
      normalizeDigitalClockOverlayConfigJsonString('{"hour24":"yes"}'),
      isNull,
    );
  });
}
