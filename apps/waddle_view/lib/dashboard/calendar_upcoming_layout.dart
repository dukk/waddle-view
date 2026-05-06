import 'dart:typed_data';

import '../blob/blob_store.dart';
import '../persistence/database.dart';
import 'calendar_month_grid.dart';

/// One calendar row with optional [ContentCategories] metadata for icons.
class CalendarSlideEventRow {
  const CalendarSlideEventRow({
    required this.event,
    this.category,
    this.categoryIconBytes,
  });

  final CalendarEvent event;
  final ContentCategory? category;
  final Uint8List? categoryIconBytes;
}

/// Stable key: shared [CalendarEvent.icalUid] or title/start/end fingerprint.
String calendarEventDedupeKey(CalendarEvent e) {
  final uid = e.icalUid?.trim();
  if (uid != null && uid.isNotEmpty) {
    return 'ical:${uid.toLowerCase()}';
  }
  return 'fp:${e.title}\x1f${e.startMs.toIso8601String()}\x1f'
      '${e.endMs.toIso8601String()}\x1f${e.allDay}';
}

/// Drops duplicates from multiple calendars (same iCal UID or identical timing/title).
List<CalendarEvent> dedupeCalendarEventsForDisplay(List<CalendarEvent> events) {
  final sorted = List<CalendarEvent>.from(events)
    ..sort((a, b) {
      final c = a.startMs.compareTo(b.startMs);
      if (c != 0) {
        return c;
      }
      return a.id.compareTo(b.id);
    });
  final seen = <String>{};
  final out = <CalendarEvent>[];
  for (final e in sorted) {
    if (seen.add(calendarEventDedupeKey(e))) {
      out.add(e);
    }
  }
  return out;
}

Future<List<CalendarSlideEventRow>> loadCalendarSlideEventRows(
  AppDatabase db,
  BlobStore blobs,
  List<CalendarEvent> events,
) async {
  final ids = events
      .map((e) => e.categoryId)
      .whereType<String>()
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  if (ids.isEmpty) {
    return events
        .map((e) => CalendarSlideEventRow(event: e))
        .toList();
  }
  final cats = await (db.select(db.contentCategories)
        ..where((t) => t.id.isIn(ids)))
      .get();
  final catById = {for (final c in cats) c.id: c};
  final bytesByCategory = <String, Uint8List>{};
  for (final c in cats) {
    final bk = c.iconBlobKey?.trim();
    if (bk == null || bk.isEmpty) {
      continue;
    }
    final meta = await (db.select(db.blobMetadata)
          ..where((t) => t.blobKey.equals(bk)))
        .getSingleOrNull();
    if (meta == null) {
      continue;
    }
    try {
      final raw = await blobs.readBytes(BlobRef(meta.relativePath));
      if (raw.isNotEmpty) {
        bytesByCategory[c.id] = Uint8List.fromList(raw);
      }
    } on Object {
      // ignore missing blob
    }
  }
  return events
      .map(
        (e) => CalendarSlideEventRow(
          event: e,
          category: e.categoryId != null ? catById[e.categoryId] : null,
          categoryIconBytes: e.categoryId != null
              ? bytesByCategory[e.categoryId]
              : null,
        ),
      )
      .toList();
}

class CalendarMonthStreamBundle {
  const CalendarMonthStreamBundle({
    required this.events,
    required this.rows,
  });

  final List<CalendarEvent> events;
  final List<CalendarSlideEventRow> rows;
}

Future<CalendarMonthStreamBundle> buildCalendarMonthStreamBundle(
  AppDatabase db,
  BlobStore blobs,
  List<CalendarEvent> events,
) async {
  final rows = await loadCalendarSlideEventRows(db, blobs, events);
  return CalendarMonthStreamBundle(events: events, rows: rows);
}

sealed class CalendarUpcomingListItem {}

class CalendarUpcomingDayHeading extends CalendarUpcomingListItem {
  CalendarUpcomingDayHeading(this.label);

  final String label;
}

class CalendarUpcomingEventEntry extends CalendarUpcomingListItem {
  CalendarUpcomingEventEntry({
    required this.row,
    required this.showTimeColumn,
    required this.timeLabel,
  });

  final CalendarSlideEventRow row;
  final bool showTimeColumn;
  final String timeLabel;
}

String _timeClusterKey(CalendarEvent e) {
  if (e.allDay) {
    return '__allday__';
  }
  return '${e.startMs.millisecondsSinceEpoch}';
}

int _sameDaySort(CalendarEvent a, CalendarEvent b) {
  if (a.allDay != b.allDay) {
    return a.allDay ? -1 : 1;
  }
  final c = a.startMs.compareTo(b.startMs);
  if (c != 0) {
    return c;
  }
  return a.id.compareTo(b.id);
}

/// Day headings + event rows; consecutive events with the same time/all-day label
/// share one time column.
List<CalendarUpcomingListItem> buildCalendarUpcomingListItems({
  required List<CalendarSlideEventRow> rows,
  required DateTime todayLocal,
}) {
  final byDay = <DateTime, List<CalendarSlideEventRow>>{};
  for (final r in rows) {
    final local = r.event.startMs.toLocal();
    final key = DateTime(local.year, local.month, local.day);
    byDay.putIfAbsent(key, () => []).add(r);
  }
  final days = byDay.keys.toList()..sort();
  final out = <CalendarUpcomingListItem>[];
  for (final day in days) {
    out.add(CalendarUpcomingDayHeading(_dayHeading(day, todayLocal)));
    final dayRows = byDay[day]!..sort((a, b) => _sameDaySort(a.event, b.event));
    String? lastKey;
    for (final r in dayRows) {
      final key = _timeClusterKey(r.event);
      final newCluster = lastKey != key;
      lastKey = key;
      final timeLabel = formatCalendarEventListTime(
        r.event.startMs,
        r.event.allDay,
      );
      out.add(
        CalendarUpcomingEventEntry(
          row: r,
          showTimeColumn: newCluster,
          timeLabel: timeLabel,
        ),
      );
    }
  }
  return out;
}

String _dayHeading(DateTime day, DateTime firstDay) {
  const long = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final delta = day.difference(firstDay).inDays;
  if (delta == 0) {
    return 'Today';
  }
  if (delta == 1) {
    return 'Tomorrow';
  }
  return long[day.weekday - 1];
}
