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

/// Formats a list-row time label; [startMs] is stored as UTC epoch ms in DB.
String formatCalendarEventListTime(int startMs, bool allDay) {
  if (allDay) {
    return 'All day';
  }
  final dt =
      DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true).toLocal();
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$h:$min';
}
