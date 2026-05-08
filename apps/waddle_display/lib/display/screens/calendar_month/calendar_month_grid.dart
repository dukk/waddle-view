// Month grid helpers (Sunday-first columns; see [buildMonthGridCells]).

/// UTC epoch ms for local midnight at the start of [now]'s calendar day.
int startOfTodayLocalMs(DateTime now) {
  final local = now.toLocal();
  final start = DateTime(local.year, local.month, local.day);
  return start.millisecondsSinceEpoch;
}

/// One cell in a fixed 7-column Sunday-first month grid.
class MonthGridCell {
  const MonthGridCell({
    required this.day,
    required this.inCurrentMonth,
    required this.isToday,
  });

  final int day;
  final bool inCurrentMonth;
  final bool isToday;
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
      ),
    );
    trailingDay++;
  }

  return out;
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

/// Formats a list-row time label for a calendar event start instant from the DB.
String formatCalendarEventListTime(
  DateTime start,
  bool allDay, {
  CalendarMonthUpcomingTimeOptions options =
      CalendarMonthUpcomingTimeOptions.defaults,
}) {
  if (allDay) {
    return 'All day';
  }
  final local = start.toLocal();
  if (options.use12Hour) {
    return _formatListTime12h(local, options.noonLabel);
  }
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$h:$min';
}
