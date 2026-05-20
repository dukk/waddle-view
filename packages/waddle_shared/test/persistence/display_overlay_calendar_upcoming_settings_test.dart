import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_calendar_upcoming_settings.dart';

void main() {
  test('parse defaults when empty', () {
    expect(
      CalendarUpcomingOverlaySettings.parse(''),
      CalendarUpcomingOverlaySettings.defaults,
    );
  });

  test('parse placement upcomingDays and time options', () {
    final s = CalendarUpcomingOverlaySettings.parseMap({
      'x': 0.8,
      'y': 0.1,
      'scale': 0.3,
      'upcomingDays': 7,
      'upcomingTime12Hour': false,
      'upcomingTimeNoonLabel': 'Midday',
      'upcomingTimeWidth': 140,
    });
    expect(s.placement.x, 0.8);
    expect(s.upcomingDays, 7);
    expect(s.upcomingTime12Hour, isFalse);
    expect(s.upcomingTimeNoonLabel, 'Midday');
    expect(s.upcomingTimeWidth, 140);
  });

  test('upcomingDays clamps to min max', () {
    expect(
      CalendarUpcomingOverlaySettings.parseMap({'upcomingDays': 0}).upcomingDays,
      kCalendarUpcomingOverlayDaysMin,
    );
    expect(
      CalendarUpcomingOverlaySettings.parseMap({'upcomingDays': 99})
          .upcomingDays,
      kCalendarUpcomingOverlayDaysMax,
    );
  });

  test('normalize strips enabled', () {
    final norm = normalizeCalendarUpcomingOverlayConfigJsonString(
      '{"enabled":true,"upcomingDays":3,"x":0.72,"y":0.05}',
    );
    expect(norm, isNotNull);
    final parsed = CalendarUpcomingOverlaySettings.parse(norm!);
    expect(parsed.upcomingDays, 3);
    expect(parsed.placement.x, closeTo(0.72, 0.001));
  });

  test('normalize rejects invalid upcomingDays type', () {
    expect(
      normalizeCalendarUpcomingOverlayConfigJsonString(
        '{"upcomingDays": "three"}',
      ),
      isNull,
    );
  });

  test('defaults use right-edge placement', () {
    expect(
      CalendarUpcomingOverlaySettings.defaults.placement.x,
      kCalendarUpcomingOverlayPositionXDefault,
    );
    expect(
      CalendarUpcomingOverlaySettings.defaults.placement.scale,
      kCalendarUpcomingOverlayScaleDefault,
    );
  });
}
