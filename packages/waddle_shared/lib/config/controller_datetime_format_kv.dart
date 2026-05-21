/// [AppDatabase.configKeyValues] key: controller SPA time display (`12h` / `24h`).
const String kControllerTimeFormatKvKey = 'controller.time_format';

/// [AppDatabase.configKeyValues] key: controller SPA date component order.
const String kControllerDateOrderKvKey = 'controller.date_order';

/// Default when the key is missing or the value is unknown.
const String kDefaultControllerTimeFormat = '12h';

/// Default when the key is missing or the value is unknown.
const String kDefaultControllerDateOrder = 'mdy';

const String kControllerTimeFormat12h = '12h';
const String kControllerTimeFormat24h = '24h';

const String kControllerDateOrderMdy = 'mdy';
const String kControllerDateOrderDmy = 'dmy';
const String kControllerDateOrderYmd = 'ymd';

const List<String> kControllerTimeFormatOptions = [
  kControllerTimeFormat12h,
  kControllerTimeFormat24h,
];

const List<String> kControllerDateOrderOptions = [
  kControllerDateOrderMdy,
  kControllerDateOrderDmy,
  kControllerDateOrderYmd,
];

/// Normalizes [raw] to `12h` or `24h`.
String normalizeControllerTimeFormat(String? raw) {
  final s = raw?.trim().toLowerCase() ?? '';
  if (s == kControllerTimeFormat24h || s == '24') {
    return kControllerTimeFormat24h;
  }
  return kDefaultControllerTimeFormat;
}

/// Normalizes [raw] to `mdy`, `dmy`, or `ymd`.
String normalizeControllerDateOrder(String? raw) {
  final s = raw?.trim().toLowerCase() ?? '';
  switch (s) {
    case kControllerDateOrderDmy:
      return kControllerDateOrderDmy;
    case kControllerDateOrderYmd:
      return kControllerDateOrderYmd;
    default:
      return kDefaultControllerDateOrder;
  }
}
