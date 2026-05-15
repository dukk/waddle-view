import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart';
import 'package:waddle_data_providers/shared/provider_calendar_date_time.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('naive dateTime uses IANA timeZone wall clock', () {
    final loc = getLocation('America/Chicago');
    final expected = TZDateTime(loc, 2024, 6, 15, 10, 0).toUtc();
    final parsed = parseCalendarApiDateTimeUtc(
      dateTimeIso: '2024-06-15T10:00:00.0000000',
      optionalTimeZoneName: 'America/Chicago',
    );
    expect(parsed, expected);
  });

  test('naive dateTime uses Windows Graph timeZone name', () {
    final loc = getLocation('America/Los_Angeles');
    final expected = TZDateTime(loc, 2024, 6, 15, 10, 0).toUtc();
    final parsed = parseCalendarApiDateTimeUtc(
      dateTimeIso: '2024-06-15T10:00:00.0000000',
      optionalTimeZoneName: 'Pacific Standard Time',
    );
    expect(parsed, expected);
  });

  test('Z suffix ignores separate timeZone hint', () {
    final parsed = parseCalendarApiDateTimeUtc(
      dateTimeIso: '2024-06-15T17:00:00Z',
      optionalTimeZoneName: 'America/New_York',
    );
    expect(parsed, DateTime.utc(2024, 6, 15, 17, 0));
  });

  test('Graph literal UTC timeZone with naive dateTime', () {
    final parsed = parseCalendarApiDateTimeUtc(
      dateTimeIso: '2026-06-01T10:00:00.0000000',
      optionalTimeZoneName: 'UTC',
    );
    expect(parsed, DateTime.utc(2026, 6, 1, 10, 0));
  });

  test('all-day date uses midnight in timeZone', () {
    final loc = getLocation('America/Los_Angeles');
    final expected = TZDateTime(loc, 2024, 6, 15).toUtc();
    final parsed = parseCalendarEventDateMapUtc({
      'date': '2024-06-15',
      'timeZone': 'America/Los_Angeles',
    }, isAllDay: true);
    expect(parsed, expected);
  });

  test('all-day without timeZone uses UTC civil midnight', () {
    final parsed = parseCalendarEventDateMapUtc(const {
      'date': '2024-06-15',
    }, isAllDay: true);
    expect(parsed, DateTime.utc(2024, 6, 15));
  });

  test('date-only map returns null when not all-day', () {
    expect(
      parseCalendarEventDateMapUtc(const {
        'date': '2024-06-15',
      }, isAllDay: false),
      isNull,
    );
  });
}
