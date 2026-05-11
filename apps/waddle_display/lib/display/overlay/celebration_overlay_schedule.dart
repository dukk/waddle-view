import '../../persistence/display_overlay_schedule_row.dart';

/// Computes the calendar date for the [nthWeekInMonth] occurrence of [weekday]
/// (Dart [DateTime.weekday], Monday=1 … Sunday=7) in [month]/[year], or null
/// when that weekday does not occur that many times in the month.
DateTime? nthWeekdayOccurrenceInMonth({
  required int year,
  required int month,
  required int nthWeekInMonth,
  required int weekday,
}) {
  if (nthWeekInMonth < 1 || nthWeekInMonth > 5) {
    return null;
  }
  if (weekday < DateTime.monday || weekday > DateTime.sunday) {
    return null;
  }
  if (month < 1 || month > 12) {
    return null;
  }

  final first = DateTime(year, month, 1);
  var delta = weekday - first.weekday;
  if (delta < 0) {
    delta += DateTime.daysPerWeek;
  }
  final firstOccurrenceDay = 1 + delta;
  final targetDay = firstOccurrenceDay + (nthWeekInMonth - 1) * DateTime.daysPerWeek;
  final lastDayOfMonth = DateTime(year, month + 1, 0).day;
  if (targetDay > lastDayOfMonth) {
    return null;
  }
  return DateTime(year, month, targetDay);
}

bool _sameCalendarDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool matchesCelebrationOverlay(
  DisplayOverlayScheduleRow row,
  DateTime localNow,
) {
  if (!row.enabled) {
    return false;
  }

  final today = DateTime(localNow.year, localNow.month, localNow.day);

  if (row.nthWeekOfMonth != null) {
    if (row.nthWeekday == null) {
      return false;
    }
    final y = row.repeatAnnually ? today.year : row.yearExact;
    if (y == null) {
      return false;
    }
    if (!row.repeatAnnually && row.yearExact != today.year) {
      return false;
    }

    final anchor = nthWeekdayOccurrenceInMonth(
      year: y,
      month: row.startMonth,
      nthWeekInMonth: row.nthWeekOfMonth!,
      weekday: row.nthWeekday!,
    );
    if (anchor == null) {
      return false;
    }
    return _sameCalendarDate(anchor, today);
  }

  final y = row.repeatAnnually ? today.year : row.yearExact;
  if (y == null) {
    return false;
  }
  if (!row.repeatAnnually && row.yearExact != today.year) {
    return false;
  }

  DateTime rangeStart;
  DateTime rangeEnd;
  try {
    rangeStart = DateTime(y, row.startMonth, row.startDay);
    final endM = row.endMonth ?? row.startMonth;
    final endD = row.endDay ?? row.startDay;
    rangeEnd = DateTime(y, endM, endD);
  } on Object {
    return false;
  }

  if (rangeStart.isAfter(rangeEnd)) {
    return false;
  }

  return !today.isBefore(rangeStart) && !today.isAfter(rangeEnd);
}
