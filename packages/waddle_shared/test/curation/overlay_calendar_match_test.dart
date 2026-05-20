import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/curation/overlay_calendar_match.dart';

void main() {
  group('nthWeekdayOccurrenceInMonth', () {
    test('returns 2nd Tuesday of May 2024', () {
      final d = nthWeekdayOccurrenceInMonth(
        year: 2024,
        month: 5,
        nthWeekInMonth: 2,
        weekday: DateTime.tuesday,
      );
      expect(d, DateTime(2024, 5, 14));
    });

    test('returns null for invalid inputs', () {
      expect(
        nthWeekdayOccurrenceInMonth(
          year: 2024,
          month: 5,
          nthWeekInMonth: 6,
          weekday: DateTime.tuesday,
        ),
        isNull,
      );
      expect(
        nthWeekdayOccurrenceInMonth(
          year: 2024,
          month: 13,
          nthWeekInMonth: 1,
          weekday: DateTime.monday,
        ),
        isNull,
      );
    });
  });

  group('sameCalendarDate', () {
    test('ignores time of day', () {
      final a = DateTime(2026, 5, 20, 23, 59);
      final b = DateTime(2026, 5, 20, 0, 1);
      expect(sameCalendarDate(a, b), isTrue);
      expect(sameCalendarDate(a, DateTime(2026, 5, 21)), isFalse);
    });
  });

  group('matchesOverlayCalendar', () {
    test('matches annual date range inclusive', () {
      final fields = OverlayCalendarFields(
        repeatAnnually: true,
        startMonth: 5,
        startDay: 10,
        endMonth: 5,
        endDay: 20,
      );
      expect(
        matchesOverlayCalendar(
          fields,
          DateTime(2026, 5, 15),
        ),
        isTrue,
      );
      expect(
        matchesOverlayCalendar(
          fields,
          DateTime(2026, 5, 9),
        ),
        isFalse,
      );
    });

    test('matches nth weekday of month when repeatAnnually', () {
      final fields = OverlayCalendarFields(
        repeatAnnually: true,
        startMonth: 5,
        startDay: 1,
        nthWeekOfMonth: 2,
        nthWeekday: DateTime.tuesday,
      );
      expect(
        matchesOverlayCalendar(
          fields,
          DateTime(2024, 5, 14),
        ),
        isTrue,
      );
      expect(
        matchesOverlayCalendar(
          fields,
          DateTime(2024, 5, 7),
        ),
        isFalse,
      );
    });

    test('requires yearExact when not repeating annually', () {
      final fields = OverlayCalendarFields(
        repeatAnnually: false,
        yearExact: 2025,
        startMonth: 12,
        startDay: 25,
      );
      expect(
        matchesOverlayCalendar(
          fields,
          DateTime(2025, 12, 25),
        ),
        isTrue,
      );
      expect(
        matchesOverlayCalendar(
          fields,
          DateTime(2026, 12, 25),
        ),
        isFalse,
      );
    });
  });

  group('daysOfWeekMask and time window', () {
    test('unrestricted mask matches any weekday', () {
      expect(daysOfWeekMaskIsUnrestricted(null), isTrue);
      expect(daysOfWeekMaskIsUnrestricted(0x7F), isTrue);
      expect(
        matchesDaysOfWeekMask(0x7F, DateTime(2026, 5, 20)),
        isTrue,
      );
    });

    test('matchesTimeWindowMinutes supports overnight window', () {
      final late = DateTime(2026, 5, 20, 23, 30);
      expect(
        matchesTimeWindowMinutes(
          startMinutes: 22 * 60,
          endMinutes: 2 * 60,
          localNow: late,
        ),
        isTrue,
      );
    });
  });
}
