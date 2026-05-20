import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_calendar_month_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_static_image_settings.dart';

void main() {
  test('parse defaults when empty', () {
    expect(
      CalendarMonthOverlaySettings.parse(''),
      CalendarMonthOverlaySettings.defaults,
    );
  });

  test('parse placement and categoryId', () {
    final s = CalendarMonthOverlaySettings.parseMap({
      'x': 0.1,
      'y': 0.2,
      'scale': 0.18,
      'categoryId': 'work',
    });
    expect(s.placement.x, 0.1);
    expect(s.placement.y, 0.2);
    expect(s.placement.scale, 0.18);
    expect(s.categoryId, 'work');
  });

  test('normalize strips enabled and messages', () {
    final norm = normalizeCalendarMonthOverlayConfigJsonString(
      '{"enabled":true,"messages":["x"],"categoryId":"family","x":0.5,"y":0.5}',
    );
    expect(norm, isNotNull);
    final parsed = CalendarMonthOverlaySettings.parse(norm!);
    expect(parsed.categoryId, 'family');
    expect(parsed.placement.x, 0.5);
  });

  test('normalize rejects invalid categoryId type', () {
    expect(
      normalizeCalendarMonthOverlayConfigJsonString('{"categoryId": 1}'),
      isNull,
    );
  });

  test('defaults use calendar month scale', () {
    expect(
      CalendarMonthOverlaySettings.defaults.placement.scale,
      kCalendarMonthOverlayScaleDefault,
    );
    expect(
      CalendarMonthOverlaySettings.defaults.placement.x,
      kStaticImageOverlayPositionDefault,
    );
  });
}
