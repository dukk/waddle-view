import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/calendar_month/calendar_month_grid.dart';

void main() {
  group('startOfTodayLocalMs', () {
    test('returns local midnight for same calendar day', () {
      final noon = DateTime(2026, 5, 4, 12, 30);
      final boundary = startOfTodayLocalMs(noon);
      final start = DateTime(2026, 5, 4);
      expect(boundary, start.millisecondsSinceEpoch);
    });
  });

  group('buildMonthGridCells', () {
    test('length is multiple of 7', () {
      final cells = buildMonthGridCells(
        DateTime(2024, 6, 1),
        DateTime(2024, 6, 15),
      );
      expect(cells.length % 7, 0);
      expect(cells.length, greaterThan(0));
    });

    test('marks today within current month', () {
      final cells = buildMonthGridCells(
        DateTime(2024, 6, 1),
        DateTime(2024, 6, 15),
      );
      final todayCells = cells.where((c) => c.isToday).toList();
      expect(todayCells, hasLength(1));
      expect(todayCells.single.day, 15);
      expect(todayCells.single.inCurrentMonth, isTrue);
    });

    test('February 2024 leap year has 29 in-month days', () {
      final cells = buildMonthGridCells(
        DateTime(2024, 2, 1),
        DateTime(2024, 2, 14),
      );
      final inMonth = cells.where((c) => c.inCurrentMonth).toList();
      expect(inMonth.length, 29);
    });

    test('no cell is today when today is another month', () {
      final cells = buildMonthGridCells(
        DateTime(2024, 3, 1),
        DateTime(2024, 6, 15),
      );
      expect(cells.any((c) => c.isToday), isFalse);
    });
  });

  group('formatCalendarEventListTime', () {
    test('all day label', () {
      expect(
        formatCalendarEventListTime(DateTime.fromMillisecondsSinceEpoch(0), true),
        'All day',
      );
    });

    test('defaults: 12-hour with PM', () {
      expect(
        formatCalendarEventListTime(
          DateTime(2024, 6, 15, 14, 7),
          false,
        ),
        '2:07 PM',
      );
    });

    test('defaults: noon label', () {
      expect(
        formatCalendarEventListTime(
          DateTime(2024, 6, 15, 12, 0),
          false,
        ),
        'Noon',
      );
    });

    test('custom noon label', () {
      expect(
        formatCalendarEventListTime(
          DateTime(2024, 6, 15, 12, 0),
          false,
          options: const CalendarMonthUpcomingTimeOptions(noonLabel: 'Midday'),
        ),
        'Midday',
      );
    });

    test('24-hour when use12Hour false', () {
      final s = formatCalendarEventListTime(
        DateTime(2024, 6, 15, 14, 7),
        false,
        options: const CalendarMonthUpcomingTimeOptions(use12Hour: false),
      );
      expect(s, '14:07');
    });

    test('fromConfig reads keys', () {
      final o = CalendarMonthUpcomingTimeOptions.fromConfig({
        'upcomingTime12Hour': false,
        'upcomingTimeNoonLabel': ' Lunch ',
        'upcomingTimeWidthCompact': 72,
        'upcomingTimeWidth': 90,
      });
      expect(o.use12Hour, isFalse);
      expect(o.noonLabel, 'Lunch');
      expect(o.timeWidthCompact, 72);
      expect(o.timeWidth, 90);
    });
  });
}
