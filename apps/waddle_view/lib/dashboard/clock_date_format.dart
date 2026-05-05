/// English long-form date for clock slides (no intl dependency).
String formatClockDate(DateTime local) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final w = weekdays[local.weekday - 1];
  final m = months[local.month - 1];
  return '$w, $m ${local.day}, ${local.year}';
}

/// 24-hour time for digital clock signage.
String formatClockTime24(DateTime local) {
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  final s = local.second.toString().padLeft(2, '0');
  return '$h:$min:$s';
}
