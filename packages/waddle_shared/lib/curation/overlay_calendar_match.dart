/// Shared calendar helpers for overlay rows and curator schedule rules.
library;

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
  final targetDay =
      firstOccurrenceDay + (nthWeekInMonth - 1) * DateTime.daysPerWeek;
  final lastDayOfMonth = DateTime(year, month + 1, 0).day;
  if (targetDay > lastDayOfMonth) {
    return null;
  }
  return DateTime(year, month, targetDay);
}

bool sameCalendarDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Calendar/date portion of a curator rule or overlay row.
class OverlayCalendarFields {
  const OverlayCalendarFields({
    required this.repeatAnnually,
    this.yearExact,
    required this.startMonth,
    required this.startDay,
    this.endMonth,
    this.endDay,
    this.nthWeekOfMonth,
    this.nthWeekday,
  });

  final bool repeatAnnually;
  final int? yearExact;
  final int startMonth;
  final int startDay;
  final int? endMonth;
  final int? endDay;
  final int? nthWeekOfMonth;
  final int? nthWeekday;
}

bool matchesOverlayCalendar(OverlayCalendarFields fields, DateTime localNow) {
  final today = DateTime(localNow.year, localNow.month, localNow.day);

  if (fields.nthWeekOfMonth != null) {
    if (fields.nthWeekday == null) {
      return false;
    }
    final y = fields.repeatAnnually ? today.year : fields.yearExact;
    if (y == null) {
      return false;
    }
    if (!fields.repeatAnnually && fields.yearExact != today.year) {
      return false;
    }

    final anchor = nthWeekdayOccurrenceInMonth(
      year: y,
      month: fields.startMonth,
      nthWeekInMonth: fields.nthWeekOfMonth!,
      weekday: fields.nthWeekday!,
    );
    if (anchor == null) {
      return false;
    }
    return sameCalendarDate(anchor, today);
  }

  final y = fields.repeatAnnually ? today.year : fields.yearExact;
  if (y == null) {
    return false;
  }
  if (!fields.repeatAnnually && fields.yearExact != today.year) {
    return false;
  }

  DateTime rangeStart;
  DateTime rangeEnd;
  try {
    rangeStart = DateTime(y, fields.startMonth, fields.startDay);
    final endM = fields.endMonth ?? fields.startMonth;
    final endD = fields.endDay ?? fields.startDay;
    rangeEnd = DateTime(y, endM, endD);
  } on Object {
    return false;
  }

  if (rangeStart.isAfter(rangeEnd)) {
    return false;
  }

  return !today.isBefore(rangeStart) && !today.isAfter(rangeEnd);
}

/// True when [mask] has no weekday restriction (null or all bits set).
bool daysOfWeekMaskIsUnrestricted(int? mask) {
  if (mask == null) {
    return true;
  }
  return mask == 0x7F;
}

/// [localNow.weekday] is Monday=1 … Sunday=7; [mask] bit0=Monday.
bool matchesDaysOfWeekMask(int? mask, DateTime localNow) {
  if (daysOfWeekMaskIsUnrestricted(mask)) {
    return true;
  }
  final bit = 1 << (localNow.weekday - 1);
  return (mask! & bit) != 0;
}

/// Inclusive start, exclusive end; supports overnight windows.
bool matchesTimeWindowMinutes({
  required int? startMinutes,
  required int? endMinutes,
  required DateTime localNow,
}) {
  if (startMinutes == null && endMinutes == null) {
    return true;
  }
  final nowMinutes = localNow.hour * 60 + localNow.minute;
  final start = startMinutes ?? 0;
  final end = endMinutes ?? 24 * 60;
  if (start == end) {
    return true;
  }
  if (start < end) {
    return nowMinutes >= start && nowMinutes < end;
  }
  return nowMinutes >= start || nowMinutes < end;
}

bool hasCalendarConstraints(OverlayCalendarFields fields) {
  if (fields.nthWeekOfMonth != null) {
    return true;
  }
  return fields.startMonth != 0 || fields.startDay != 0;
}

bool ruleHasCalendarOrTimeConstraints({
  required int? daysOfWeekMask,
  required int? startTimeMinutes,
  required int? endTimeMinutes,
  required int? startMonth,
  required int? startDay,
  required int? nthWeekOfMonth,
}) {
  if (!daysOfWeekMaskIsUnrestricted(daysOfWeekMask)) {
    return true;
  }
  if (startTimeMinutes != null || endTimeMinutes != null) {
    return true;
  }
  if (nthWeekOfMonth != null) {
    return true;
  }
  if (startMonth != null &&
      startDay != null &&
      (startMonth != 0 || startDay != 0)) {
    return true;
  }
  return false;
}
