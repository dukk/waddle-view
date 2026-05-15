import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart';
import 'package:waddle_display/display/screens/calendar_month/calendar_upcoming_layout.dart';
import 'package:waddle_shared/persistence/database.dart';

CalendarEvent _ev({
  required String id,
  required String title,
  required DateTime start,
  required DateTime end,
  bool allDay = false,
  String? icalUid,
  String source = 't',
  String? categoryId,
}) {
  return CalendarEvent(
    id: id,
    title: title,
    startMs: start,
    endMs: end,
    allDay: allDay,
    source: source,
    updatedAtMs: start,
    icalUid: icalUid,
    categoryId: categoryId,
  );
}

void main() {
  late final Location utc;
  setUpAll(() {
    tz_data.initializeTimeZones();
    utc = getLocation('Etc/UTC');
  });

  test('dedupeCalendarEventsForDisplay keeps one per icalUid', () {
    final t = DateTime.utc(2024, 6, 15, 10);
    final d = dedupeCalendarEventsForDisplay([
      _ev(id: 'a', title: 'Meet', start: t, end: t.add(const Duration(hours: 1)), icalUid: 'UID1'),
      _ev(id: 'b', title: 'Meet', start: t, end: t.add(const Duration(hours: 1)), icalUid: 'UID1'),
      _ev(id: 'c', title: 'Other', start: t.add(const Duration(hours: 2)), end: t.add(const Duration(hours: 3))),
    ]);
    expect(d.map((e) => e.id).toList(), ['a', 'c']);
  });

  test('dedupe falls back to title/start fingerprint', () {
    final t = DateTime.utc(2024, 6, 15, 10);
    final d = dedupeCalendarEventsForDisplay([
      _ev(id: 'a', title: 'X', start: t, end: t.add(const Duration(hours: 1))),
      _ev(id: 'b', title: 'X', start: t, end: t.add(const Duration(hours: 1))),
    ]);
    expect(d.length, 1);
    expect(d.single.id, 'a');
  });

  test('buildCalendarUpcomingListItems shares time for same slot', () {
    final day0 = DateTime.utc(2024, 6, 15);
    final t1 = DateTime.utc(2024, 6, 15, 9);
    final t2 = DateTime.utc(2024, 6, 15, 9);
    final rows = [
      CalendarSlideEventRow(
        event: _ev(id: 'a', title: 'One', start: t1, end: t1.add(const Duration(hours: 1))),
      ),
      CalendarSlideEventRow(
        event: _ev(id: 'b', title: 'Two', start: t2, end: t2.add(const Duration(hours: 1))),
      ),
    ];
    final items = buildCalendarUpcomingListItems(
      rows: rows,
      todayLocal: day0,
      displayZone: utc,
    );
    final entries = items.whereType<CalendarUpcomingEventEntry>().toList();
    expect(entries.length, 2);
    expect(entries[0].showTimeColumn, isTrue);
    expect(entries[1].showTimeColumn, isFalse);
  });

  test('all-day cluster shares one time label', () {
    final day0 = DateTime.utc(2024, 6, 15);
    final sameDay = DateTime.utc(2024, 6, 16);
    final rows = [
      CalendarSlideEventRow(
        event: _ev(
          id: 'a',
          title: 'Holiday',
          start: sameDay,
          end: sameDay,
          allDay: true,
        ),
      ),
      CalendarSlideEventRow(
        event: _ev(
          id: 'b',
          title: 'Party',
          start: sameDay,
          end: sameDay,
          allDay: true,
        ),
      ),
    ];
    final items = buildCalendarUpcomingListItems(
      rows: rows,
      todayLocal: day0,
      displayZone: utc,
    );
    final entries = items.whereType<CalendarUpcomingEventEntry>().toList();
    expect(entries.length, 2);
    expect(entries[0].showTimeColumn, isTrue);
    expect(entries[1].showTimeColumn, isFalse);
  });

  test('buildCalendarMonthDayMarkersByDay splits all-day vs timed', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    final rows = [
      CalendarSlideEventRow(
        event: _ev(
          id: 'timed',
          title: 'Meet',
          start: DateTime.utc(2024, 6, 10, 15, 0),
          end: DateTime.utc(2024, 6, 10, 16, 0),
        ),
      ),
      CalendarSlideEventRow(
        event: _ev(
          id: 'allday',
          title: 'Trip',
          start: DateTime.utc(2024, 6, 12),
          end: DateTime.utc(2024, 6, 13),
          allDay: true,
        ),
      ),
    ];
    final map = buildCalendarMonthDayMarkersByDay(
      rows: rows,
      displayZone: utc,
      monthAnchor: DateTime.utc(2024, 6, 15),
      colorScheme: scheme,
    );
    expect(map[10]!.timedDotColors, hasLength(1));
    expect(map[10]!.allDayTopColors, isEmpty);
    expect(map[12]!.allDayTopColors, hasLength(1));
    expect(map[12]!.timedDotColors, isEmpty);
  });

  test('buildCalendarMonthDayMarkersByDay spans multi-day timed events', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    final rows = [
      CalendarSlideEventRow(
        event: _ev(
          id: 'span',
          title: 'Retreat',
          start: DateTime.utc(2024, 6, 17, 10, 0),
          end: DateTime.utc(2024, 6, 18, 11, 0),
        ),
      ),
    ];
    final map = buildCalendarMonthDayMarkersByDay(
      rows: rows,
      displayZone: utc,
      monthAnchor: DateTime.utc(2024, 6, 1),
      colorScheme: scheme,
    );
    expect(map[17]!.timedDotColors, hasLength(1));
    expect(map[18]!.timedDotColors, hasLength(1));
  });

  test('calendarEventMarkerAccent is stable and uses palette colors', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.deepOrange);
    final palette = calendarEventMarkerAccentPalette(scheme);
    final e = _ev(
      id: 'stable',
      title: 'A',
      start: DateTime.utc(2024, 1, 1),
      end: DateTime.utc(2024, 1, 1, 1),
      source: 'google_calendar',
      categoryId: 'work',
    );
    final c = calendarEventMarkerAccent(scheme, e);
    expect(palette, contains(c));
    expect(calendarEventMarkerAccent(scheme, e), c);
    final distinct = <Color>{
      calendarEventMarkerAccent(
        scheme,
        _ev(
          id: '1',
          title: 'A',
          start: DateTime.utc(2024, 1, 1),
          end: DateTime.utc(2024, 1, 1, 1),
          source: 'google_calendar',
          categoryId: 'work',
        ),
      ),
      calendarEventMarkerAccent(
        scheme,
        _ev(
          id: '2',
          title: 'B',
          start: DateTime.utc(2024, 1, 2),
          end: DateTime.utc(2024, 1, 2, 1),
          source: 'google_calendar',
          categoryId: 'family',
        ),
      ),
      calendarEventMarkerAccent(
        scheme,
        _ev(
          id: '3',
          title: 'C',
          start: DateTime.utc(2024, 1, 3),
          end: DateTime.utc(2024, 1, 3, 1),
          source: 'outlook_calendar',
          categoryId: 'work',
        ),
      ),
    };
    expect(distinct.length, greaterThanOrEqualTo(2));
  });
}
