import 'package:waddle_shared/config/controller_datetime_format_kv.dart';

const _tickerMediumMonthNames = [
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

/// Medium-style date for the ticker marquee (no intl dependency).
///
/// [dateOrder] is `mdy`, `dmy`, or `ymd` (see [kControllerDateOrderOptions]).
String formatTickerDateMedium(DateTime local, String dateOrder) {
  final month = _tickerMediumMonthNames[local.month - 1];
  switch (normalizeControllerDateOrder(dateOrder)) {
    case kControllerDateOrderDmy:
      return '${local.day} $month ${local.year}';
    case kControllerDateOrderYmd:
      final m = local.month.toString().padLeft(2, '0');
      final d = local.day.toString().padLeft(2, '0');
      return '${local.year}-$m-$d';
    case kControllerDateOrderMdy:
    default:
      return '$month ${local.day}, ${local.year}';
  }
}

/// Date and time matching Display settings (medium date + short time).
String formatTickerDateTimeDisplayStyle(
  DateTime local, {
  required String dateOrder,
  required String controllerTimeFormat,
}) {
  final date = formatTickerDateMedium(local, dateOrder);
  final hour24 =
      normalizeControllerTimeFormat(controllerTimeFormat) ==
      kControllerTimeFormat24h;
  final time = formatDigitalClockTime(
    local,
    hour24: hour24,
    showSeconds: false,
  );
  return '$date, $time';
}

/// Date and time with an explicit ticker [timeFormatPreset].
String formatTickerDateTime(
  DateTime local, {
  required String dateOrder,
  required String timeFormatPreset,
}) {
  final date = formatTickerDateMedium(local, dateOrder);
  final time = formatTickerTimePreset(local, timeFormatPreset);
  return '$date, $time';
}

/// True when the marquee should refresh every second.
bool tickerDateTimeNeedsSecondTimer(String? timeFormatPreset) {
  if (timeFormatPreset == null) {
    return false;
  }
  return tickerTimePresetShowsSeconds(timeFormatPreset);
}

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

/// Ticker marquee time presets (see [kTickerTimeFormatPresets] in waddle_shared).
String formatTickerTimePreset(DateTime local, String preset) {
  switch (preset) {
    case '24h_hm':
      return formatDigitalClockTime(local, hour24: true, showSeconds: false);
    case '12h_hms_ampm':
      return formatDigitalClockTime(local, hour24: false, showSeconds: true);
    case '12h_hm_ampm':
      return formatDigitalClockTime(local, hour24: false, showSeconds: false);
    case '12h_hm_tt':
      return _formatTickerCompact12h(local, showSeconds: false);
    case '24h_hms':
    default:
      return formatDigitalClockTime(local, hour24: true, showSeconds: true);
  }
}

bool tickerTimePresetShowsSeconds(String preset) {
  switch (preset) {
    case '24h_hm':
    case '12h_hm_ampm':
    case '12h_hm_tt':
      return false;
    default:
      return true;
  }
}

String _formatTickerCompact12h(DateTime local, {required bool showSeconds}) {
  final h12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final min = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'am' : 'pm';
  if (showSeconds) {
    final s = local.second.toString().padLeft(2, '0');
    return '$h12:$min:$s$period';
  }
  return '$h12:$min$period';
}
