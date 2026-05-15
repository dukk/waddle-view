import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart';

bool _providerCalendarTzDataLoaded = false;

void ensureProviderCalendarTimeZonesInitialized() {
  if (_providerCalendarTzDataLoaded) {
    return;
  }
  tz_data.initializeTimeZones();
  _providerCalendarTzDataLoaded = true;
}

/// Microsoft Graph / Windows calendar zone display names → IANA (subset).
///
/// Graph often returns `timeZone` like `Pacific Standard Time` (includes DST).
const Map<String, String> kWindowsCalendarTimeZoneToIana = {
  'dateline standard time': 'Etc/GMT+12',
  'utc-11': 'Etc/GMT+11',
  'aleutian standard time': 'America/Adak',
  'hawaiian standard time': 'Pacific/Honolulu',
  'marquesas standard time': 'Pacific/Marquesas',
  'alaskan standard time': 'America/Anchorage',
  'utc-09': 'Etc/GMT+9',
  'pacific standard time (mexico)': 'America/Tijuana',
  'pacific standard time': 'America/Los_Angeles',
  'us mountain standard time': 'America/Phoenix',
  'mountain standard time (mexico)': 'America/Chihuahua',
  'mountain standard time': 'America/Denver',
  'central america standard time': 'America/Guatemala',
  'central standard time': 'America/Chicago',
  'easter island standard time': 'Pacific/Easter',
  'sa pacific standard time': 'America/Bogota',
  'eastern standard time': 'America/New_York',
  'us eastern standard time': 'America/Indianapolis',
  'paraguay standard time': 'America/Asuncion',
  'atlantic standard time': 'America/Halifax',
  'newfoundland standard time': 'America/St_Johns',
  'utc-02': 'Etc/GMT+2',
  'greenland standard time': 'America/Nuuk',
  'utc': 'Etc/UTC',
  'gmt standard time': 'Europe/London',
  'greenwich standard time': 'Atlantic/Reykjavik',
  'w. europe standard time': 'Europe/Berlin',
  'central european standard time': 'Europe/Warsaw',
  'romance standard time': 'Europe/Paris',
  'south africa standard time': 'Africa/Johannesburg',
  'israel standard time': 'Asia/Jerusalem',
  'arabian standard time': 'Asia/Dubai',
  'iran standard time': 'Asia/Tehran',
  'arab standard time': 'Asia/Riyadh',
  'arabic standard time': 'Asia/Baghdad',
  'india standard time': 'Asia/Kolkata',
  'sri lanka standard time': 'Asia/Colombo',
  'singapore standard time': 'Asia/Singapore',
  'china standard time': 'Asia/Shanghai',
  'tokyo standard time': 'Asia/Tokyo',
  'korea standard time': 'Asia/Seoul',
  'aus eastern standard time': 'Australia/Sydney',
  'new zealand standard time': 'Pacific/Auckland',
};

Location resolveCalendarApiTimeZoneLocation(String? timeZoneName) {
  ensureProviderCalendarTimeZonesInitialized();
  final raw = (timeZoneName ?? '').trim();
  if (raw.isEmpty) {
    return getLocation('Etc/UTC');
  }
  final upper = raw.toUpperCase();
  if (upper == 'UTC') {
    return getLocation('Etc/UTC');
  }
  try {
    return getLocation(raw);
  } on Object {
    // fall through
  }
  final iana = kWindowsCalendarTimeZoneToIana[raw.toLowerCase()];
  if (iana != null) {
    try {
      return getLocation(iana);
    } on Object {
      // fall through
    }
  }
  return getLocation('Etc/UTC');
}

bool _isoDateTimeHasExplicitUtcOrOffset(String iso) {
  final t = iso.trim();
  if (t.endsWith('Z') || t.endsWith('z')) {
    return true;
  }
  return RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(t);
}

/// Interprets a Google / Graph `start`/`end` map as a UTC instant for persistence.
///
/// - RFC3339 values with `Z` or a numeric offset use the embedded instant.
/// - Naive `dateTime` strings use [timeZone] (IANA or common Windows names).
/// - All-day `date` uses midnight on that civil date in [timeZone], or UTC if
///   no zone is given (stable across collector hosts).
DateTime? parseCalendarEventDateMapUtc(
  Map<String, dynamic>? raw, {
  required bool isAllDay,
}) {
  if (raw == null) {
    return null;
  }
  final tzRaw = raw['timeZone'];
  final tzName = tzRaw is String ? tzRaw.trim() : null;

  final dateTimeStr = raw['dateTime'];
  if (dateTimeStr is String && dateTimeStr.isNotEmpty) {
    return parseCalendarApiDateTimeUtc(
      dateTimeIso: dateTimeStr,
      optionalTimeZoneName: tzName,
    );
  }

  final dateStr = raw['date'];
  if (isAllDay && dateStr is String && dateStr.isNotEmpty) {
    return parseCalendarApiAllDayStartUtc(
      date: dateStr,
      optionalTimeZoneName: tzName,
    );
  }
  return null;
}

DateTime? parseCalendarApiDateTimeUtc({
  required String dateTimeIso,
  String? optionalTimeZoneName,
}) {
  ensureProviderCalendarTimeZonesInitialized();
  final parsed = DateTime.tryParse(dateTimeIso);
  if (parsed == null) {
    return null;
  }
  if (parsed.isUtc || _isoDateTimeHasExplicitUtcOrOffset(dateTimeIso)) {
    return parsed.toUtc();
  }
  final loc = resolveCalendarApiTimeZoneLocation(optionalTimeZoneName);
  return TZDateTime(
    loc,
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  ).toUtc();
}

DateTime? parseCalendarApiAllDayStartUtc({
  required String date,
  String? optionalTimeZoneName,
}) {
  ensureProviderCalendarTimeZonesInitialized();
  final parts = date.split('-');
  if (parts.length != 3) {
    return DateTime.tryParse('${date}T00:00:00')?.toUtc();
  }
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) {
    return null;
  }
  final trimmedTz = (optionalTimeZoneName ?? '').trim();
  if (trimmedTz.isEmpty) {
    return DateTime.utc(y, m, d);
  }
  final loc = resolveCalendarApiTimeZoneLocation(optionalTimeZoneName);
  return TZDateTime(loc, y, m, d).toUtc();
}
