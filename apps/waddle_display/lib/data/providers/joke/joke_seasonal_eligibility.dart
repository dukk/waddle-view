import 'package:meta/meta.dart';

import 'package:waddle_shared/persistence/database.dart';

/// Month/day as a single comparable int (e.g. March 5 => 305).
@visibleForTesting
int monthDayKey(int month, int day) => month * 100 + day;

/// [localDay] should be a calendar date in local time (any time on that day).
bool isDateInAnnualSeasonWindow(
  DateTime localDay, {
  required int startMonth,
  required int startDay,
  required int endMonth,
  required int endDay,
}) {
  final start = monthDayKey(startMonth, startDay);
  final end = monthDayKey(endMonth, endDay);
  final today = monthDayKey(localDay.month, localDay.day);
  if (start <= end) {
    return today >= start && today <= end;
  }
  // Spans New Year (e.g. Dec 1 — Jan 6).
  return today >= start || today <= end;
}

/// Whether a category may be used for generation on [now] (local time).
bool isJokeCategoryEligibleOn(JokeCategory row, DateTime now) {
  if (!row.isSeasonal) {
    return true;
  }
  final sm = row.startMonth;
  final sd = row.startDay;
  final em = row.endMonth;
  final ed = row.endDay;
  if (sm == null || sd == null || em == null || ed == null) {
    return false;
  }
  final localDay = DateTime(now.year, now.month, now.day);
  return isDateInAnnualSeasonWindow(
    localDay,
    startMonth: sm,
    startDay: sd,
    endMonth: em,
    endDay: ed,
  );
}
