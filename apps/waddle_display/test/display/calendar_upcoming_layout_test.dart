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
}) {
  return CalendarEvent(
    id: id,
    title: title,
    startMs: start,
    endMs: end,
    allDay: allDay,
    source: 't',
    updatedAtMs: start,
    icalUid: icalUid,
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
}
