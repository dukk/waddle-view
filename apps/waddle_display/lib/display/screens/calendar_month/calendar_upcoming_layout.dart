import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/blob/display_blob_read.dart';
import 'package:waddle_shared/persistence/database.dart';

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
    final read = await readDisplayBlobBytes(blobs, BlobRef(meta.relativePath));
    if (read.bytes != null) {
      bytesByCategory[c.id] = read.bytes!;
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

/// Accent colors used for month-grid event markers (dots / all-day squares).
List<Color> calendarEventMarkerAccentPalette(ColorScheme scheme) => [
  scheme.primary,
  scheme.tertiary,
  scheme.secondary,
  scheme.error,
  scheme.surfaceTint,
  scheme.primaryContainer,
];

/// Picks a stable accent from [calendarEventMarkerAccentPalette] using category,
/// calendar [CalendarEvent.source], and event id.
Color calendarEventMarkerAccent(ColorScheme scheme, CalendarEvent event) {
  final cat = event.categoryId?.trim() ?? '';
  final src = event.source.trim();
  final h = Object.hash(cat, src, event.id);
  final palette = calendarEventMarkerAccentPalette(scheme);
  return palette[h.abs() % palette.length];
}

/// Per-day markers for the calendar month grid (keys: `1..daysInMonth`).
class CalendarMonthDayMarkers {
  const CalendarMonthDayMarkers({
    this.allDayTopColors = const [],
    this.timedDotColors = const [],
  });

  static const empty = CalendarMonthDayMarkers();

  final List<Color> allDayTopColors;
  final List<Color> timedDotColors;

  bool get isEmpty => allDayTopColors.isEmpty && timedDotColors.isEmpty;
}

/// Maps each day of [monthAnchor]'s month to marker colors from [rows].
Map<int, CalendarMonthDayMarkers> buildCalendarMonthDayMarkersByDay({
  required List<CalendarSlideEventRow> rows,
  required Location displayZone,
  required DateTime monthAnchor,
  required ColorScheme colorScheme,
}) {
  final y = monthAnchor.year;
  final m = monthAnchor.month;
  final monthStart = TZDateTime(displayZone, y, m, 1);
  final monthEndExclusive = m < 12
      ? TZDateTime(displayZone, y, m + 1, 1)
      : TZDateTime(displayZone, y + 1, 1, 1);
  final daysInMonth =
      monthEndExclusive.difference(monthStart).inDays.clamp(1, 31);

  final byDay = <int, List<CalendarSlideEventRow>>{};
  for (final row in rows) {
    final e = row.event;
    for (var d = 1; d <= daysInMonth; d++) {
      final cellDate = DateTime(y, m, d);
      final bool touches;
      if (e.allDay) {
        touches = calendarAllDayCivilRangesOverlap(
          e.startMs,
          e.endMs,
          cellDate,
          cellDate.add(const Duration(days: 1)),
        );
      } else {
        final startMs = e.startMs.millisecondsSinceEpoch;
        final endMs = e.endMs.millisecondsSinceEpoch;
        final dayStart = TZDateTime(displayZone, y, m, d);
        final dayEnd = dayStart.add(const Duration(days: 1));
        final ds = dayStart.millisecondsSinceEpoch;
        final de = dayEnd.millisecondsSinceEpoch;
        touches = startMs < de && endMs > ds;
      }
      if (touches) {
        byDay.putIfAbsent(d, () => []).add(row);
      }
    }
  }

  final out = <int, CalendarMonthDayMarkers>{};
  for (final entry in byDay.entries) {
    final sorted = List<CalendarSlideEventRow>.from(entry.value)
      ..sort((a, b) {
        final c = a.event.startMs.compareTo(b.event.startMs);
        if (c != 0) {
          return c;
        }
        return a.event.id.compareTo(b.event.id);
      });
    final allDay = <Color>[];
    final timed = <Color>[];
    for (final r in sorted) {
      final c = calendarEventMarkerAccent(colorScheme, r.event);
      if (r.event.allDay) {
        allDay.add(c);
      } else {
        timed.add(c);
      }
    }
    out[entry.key] = CalendarMonthDayMarkers(
      allDayTopColors: allDay,
      timedDotColors: timed,
    );
  }
  return out;
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

String _timeClusterKey(CalendarEvent e, Location displayZone) {
  if (e.allDay) {
    return '__allday__';
  }
  final z = calendarInstantInZone(e.startMs, displayZone);
  return '${z.year}-${z.month}-${z.day}-${z.hour}-${z.minute}';
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
  required Location displayZone,
  CalendarMonthUpcomingTimeOptions timeOptions =
      CalendarMonthUpcomingTimeOptions.defaults,
}) {
  final byDay = <DateTime, List<CalendarSlideEventRow>>{};
  for (final r in rows) {
    final DateTime key;
    if (r.event.allDay) {
      key = calendarAllDayCivilDateFromStoredUtc(r.event.startMs);
    } else {
      final z = calendarInstantInZone(r.event.startMs, displayZone);
      key = DateTime(z.year, z.month, z.day);
    }
    byDay.putIfAbsent(key, () => []).add(r);
  }
  final days = byDay.keys.toList()..sort();
  final out = <CalendarUpcomingListItem>[];
  for (final day in days) {
    out.add(CalendarUpcomingDayHeading(_dayHeading(day, todayLocal)));
    final dayRows = byDay[day]!..sort((a, b) => _sameDaySort(a.event, b.event));
    String? lastKey;
    for (final r in dayRows) {
      final key = _timeClusterKey(r.event, displayZone);
      final newCluster = lastKey != key;
      lastKey = key;
      final timeLabel = formatCalendarEventListTime(
        r.event.startMs,
        r.event.allDay,
        displayZone: displayZone,
        options: timeOptions,
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
