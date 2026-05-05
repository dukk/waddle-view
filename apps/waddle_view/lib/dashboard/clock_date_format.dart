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

/// Local time for the digital clock slide.
///
/// [hour24]: 24-hour vs 12-hour with AM/PM.
/// [showSeconds]: append `:ss` when true.
String formatDigitalClockTime(
  DateTime local, {
  required bool hour24,
  required bool showSeconds,
}) {
  if (hour24) {
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    if (showSeconds) {
      final s = local.second.toString().padLeft(2, '0');
      return '$h:$min:$s';
    }
    return '$h:$min';
  }
  final h12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour < 12 ? 'AM' : 'PM';
  final min = local.minute.toString().padLeft(2, '0');
  if (showSeconds) {
    final s = local.second.toString().padLeft(2, '0');
    return '$h12:$min:$s $period';
  }
  return '$h12:$min $period';
}

/// 24-hour time with seconds (legacy helper for tests and fixed-format use).
String formatClockTime24(DateTime local) =>
    formatDigitalClockTime(local, hour24: true, showSeconds: true);
