// Month grid helpers (Sunday-first columns; see [buildMonthGridCells]).

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart';

/// Interprets [stored] as an absolute instant and returns its wall clock in [zone].
TZDateTime calendarInstantInZone(DateTime stored, Location zone) {
  final utc = stored.toUtc();
  return TZDateTime.from(utc, zone);
}

/// UTC epoch ms for midnight at the start of [now]'s calendar day in [zone].
int startOfTodayInZoneMs(Location zone, DateTime now) {
  final wall = calendarInstantInZone(now, zone);
  final start = TZDateTime(zone, wall.year, wall.month, wall.day);
  return start.millisecondsSinceEpoch;
}

/// UTC epoch ms for midnight on the first day of [now]'s calendar month in [zone].
int startOfMonthInZoneMs(Location zone, DateTime now) {
  final wall = calendarInstantInZone(now, zone);
  final start = TZDateTime(zone, wall.year, wall.month, 1);
  return start.millisecondsSinceEpoch;
}

/// One cell in a fixed 7-column Sunday-first month grid.
class MonthGridCell {
  const MonthGridCell({
    required this.day,
    required this.inCurrentMonth,
    required this.isToday,
    required this.calendarDate,
  });

  final int day;
  final bool inCurrentMonth;
  final bool isToday;

  /// Wall-calendar date this cell represents (year/month/day; time ignored).
  final DateTime calendarDate;
}

/// Builds day cells for [monthAnchor]'s month (year/month taken from local date).
/// [todayLocal] determines which cell is “today”.
List<MonthGridCell> buildMonthGridCells(
  DateTime monthAnchor,
  DateTime todayLocal,
) {
  final y = monthAnchor.year;
  final m = monthAnchor.month;
  final first = DateTime(y, m, 1);
  final leading = first.weekday % 7;
  final prevLast = first.subtract(const Duration(days: 1));
  final prevMonthDays = prevLast.day;

  final out = <MonthGridCell>[];
  for (var i = 0; i < leading; i++) {
    final dayNum = prevMonthDays - leading + i + 1;
    out.add(
      MonthGridCell(
        day: dayNum,
        inCurrentMonth: false,
        isToday: false,
        calendarDate: DateTime(prevLast.year, prevLast.month, dayNum),
      ),
    );
  }

  final nextFirst =
      m < 12 ? DateTime(y, m + 1, 1) : DateTime(y + 1, 1, 1);
  final last = nextFirst.subtract(const Duration(days: 1));
  final daysInMonth = last.day;

  final t = todayLocal.toLocal();
  for (var d = 1; d <= daysInMonth; d++) {
    final isToday = t.year == y && t.month == m && t.day == d;
    out.add(
      MonthGridCell(
        day: d,
        inCurrentMonth: true,
        isToday: isToday,
        calendarDate: DateTime(y, m, d),
      ),
    );
  }

  var trailingDay = 1;
  while (out.length % 7 != 0) {
    out.add(
      MonthGridCell(
        day: trailingDay,
        inCurrentMonth: false,
        isToday: false,
        calendarDate: DateTime(nextFirst.year, nextFirst.month, trailingDay),
      ),
    );
    trailingDay++;
  }

  return out;
}

/// Normalizes [d] to a date-only value (time components ignored).
DateTime calendarDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Fill for a month grid cell: today uses [ColorScheme.secondaryContainer];
/// adjacent-month days are left clear (same as the former in-month future look);
/// in-month days after [displayTodayDateOnly] use the stronger [ColorScheme.surface]
/// tint that was previously used for adjacent-month cells.
Color? calendarMonthDayCellFill(
  ColorScheme scheme,
  MonthGridCell cell,
  DateTime displayTodayDateOnly,
) {
  if (cell.isToday) {
    return scheme.secondaryContainer;
  }
  if (!cell.inCurrentMonth) {
    return null;
  }
  final cellDay = calendarDateOnly(cell.calendarDate);
  final todayDay = calendarDateOnly(displayTodayDateOnly);
  if (cellDay.isBefore(todayDay)) {
    return Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.10),
      scheme.surface,
    );
  }
  if (cellDay.isAfter(todayDay)) {
    return Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.22),
      scheme.surface,
    );
  }
  return null;
}

/// Layout and formatting for upcoming-event time labels on the [calendar_month] slide.
class CalendarMonthUpcomingTimeOptions {
  const CalendarMonthUpcomingTimeOptions({
    this.use12Hour = true,
    this.noonLabel = 'Noon',
    this.timeWidthCompact = 132,
    this.timeWidth = 156,
  });

  /// When true, times use `h:mm AM/PM` and [noonLabel] replaces 12:00 PM.
  final bool use12Hour;

  /// Replaces exactly local 12:00 (noon); midnight stays `12:00 AM`.
  final String noonLabel;

  /// Time column width in logical pixels before viewport scale (compact slide height).
  final double timeWidthCompact;

  /// Time column width before scale (non-compact).
  final double timeWidth;

  static const defaults = CalendarMonthUpcomingTimeOptions();

  static CalendarMonthUpcomingTimeOptions fromConfig(
    Map<String, dynamic> config,
  ) {
    final twelve = config['upcomingTime12Hour'];
    final use12 = twelve is bool ? twelve : true;
    final noonRaw = config['upcomingTimeNoonLabel'];
    final noon = noonRaw is String && noonRaw.trim().isNotEmpty
        ? noonRaw.trim()
        : 'Noon';
    var cw = 132.0;
    var nw = 156.0;
    final wc = config['upcomingTimeWidthCompact'];
    final w = config['upcomingTimeWidth'];
    if (wc is num && wc.toDouble() > 0) {
      cw = wc.toDouble();
    }
    if (w is num && w.toDouble() > 0) {
      nw = w.toDouble();
    }
    return CalendarMonthUpcomingTimeOptions(
      use12Hour: use12,
      noonLabel: noon,
      timeWidthCompact: cw,
      timeWidth: nw,
    );
  }
}

String _formatListTime12h(DateTime local, String noonLabel) {
  final h = local.hour;
  final m = local.minute;
  if (h == 12 && m == 0) {
    return noonLabel;
  }
  final period = h < 12 ? 'AM' : 'PM';
  var displayHour = h % 12;
  if (displayHour == 0) {
    displayHour = 12;
  }
  final minStr = m.toString().padLeft(2, '0');
  return '$displayHour:$minStr $period';
}

/// Formats a list-row time label for a calendar event start instant from the DB
/// (stored as a UTC instant) using [displayZone] wall clock.
String formatCalendarEventListTime(
  DateTime start,
  bool allDay, {
  required Location displayZone,
  CalendarMonthUpcomingTimeOptions options =
      CalendarMonthUpcomingTimeOptions.defaults,
}) {
  if (allDay) {
    return 'All day';
  }
  final z = calendarInstantInZone(start, displayZone);
  final local = DateTime(z.year, z.month, z.day, z.hour, z.minute);
  if (options.use12Hour) {
    return _formatListTime12h(local, options.noonLabel);
  }
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$h:$min';
}
