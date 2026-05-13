import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

bool _displayTimeZonesInitialized = false;

/// Loads the IANA tz database (idempotent). Call from app bootstrap before [resolveDisplayTimeZoneLocation].
void ensureDisplayTimeZonesInitialized() {
  if (_displayTimeZonesInitialized) {
    return;
  }
  tz_data.initializeTimeZones();
  _displayTimeZonesInitialized = true;
}

/// Resolves [kvValue] to a [tz.Location], falling back to [kDefaultDisplayTimezoneIana] when empty or invalid.
tz.Location resolveDisplayTimeZoneLocation(String? kvValue) {
  ensureDisplayTimeZonesInitialized();
  final trimmed = (kvValue ?? '').trim();
  final iana =
      trimmed.isEmpty ? kDefaultDisplayTimezoneIana : trimmed;
  try {
    return tz.getLocation(iana);
  } on Object {
    return tz.getLocation(kDefaultDisplayTimezoneIana);
  }
}

/// Returns a trimmed IANA id or null when [raw] is null/blank.
String? trimmedDisplayTimezoneIanaOrNull(String? raw) {
  final t = (raw ?? '').trim();
  return t.isEmpty ? null : t;
}

/// True when [raw] trims to a non-empty string (before IANA validation).
bool hasNonEmptyDisplayTimezoneRaw(String? raw) {
  return trimmedDisplayTimezoneIanaOrNull(raw) != null;
}

/// Yields the current `display.timezone` value once, then follows the table
/// [watch] so the first emission matches SQLite.
Stream<String?> watchDisplayTimezoneKv(AppDatabase db) async* {
  final row = await (db.select(db.configKeyValues)
        ..where((t) => t.key.equals(kDisplayTimezoneKvKey)))
      .getSingleOrNull();
  yield row?.value;
  yield* (db.select(db.configKeyValues)
        ..where((t) => t.key.equals(kDisplayTimezoneKvKey)))
      .watch()
      .map(
        (rows) => rows.isNotEmpty ? rows.single.value : null,
      );
}
