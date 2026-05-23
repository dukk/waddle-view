import 'package:drift/drift.dart' show OrderingTerm, Value;

import 'package:waddle_shared/persistence/database.dart';
import 'weather_provider_extra_config.dart';

/// Synthetic [InterestsLocations.id] when no row has [InterestsLocation.includeWeather].
/// Collectors must call [ensureSyntheticDefaultInterestsLocation] before writing
/// [weather_current] or [weather_alerts] (both FK to [interests_locations]).
const String kSyntheticDefaultWeatherLocationId = 'default';

/// [InterestsLocations] rows with [InterestsLocation.includeWeather], or a
/// single synthetic [kSyntheticDefaultWeatherLocationId] when none.
class WeatherCollectLocation {
  const WeatherCollectLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
}

Future<List<WeatherCollectLocation>> resolveWeatherLocationsForCollect(
  AppDatabase db, {
  WeatherLocationConfig? fallbackWhenEmpty,
}) async {
  final rows = await (db.select(db.interestsLocations)
        ..where((t) => t.includeWeather.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .get();
  if (rows.isNotEmpty) {
    return rows
        .map(
          (r) => WeatherCollectLocation(
            id: r.id,
            name: r.name,
            lat: r.latitude,
            lon: r.longitude,
          ),
        )
        .toList();
  }
  final fallback = fallbackWhenEmpty;
  if (fallback == null) {
    return const [];
  }
  return [
    WeatherCollectLocation(
      id: kSyntheticDefaultWeatherLocationId,
      name: fallback.name,
      lat: fallback.latitude,
      lon: fallback.longitude,
    ),
  ];
}

/// Upserts [interests_locations] for [kSyntheticDefaultWeatherLocationId] so
/// weather tables can reference it under SQLite foreign keys.
Future<void> ensureSyntheticDefaultInterestsLocation(
  AppDatabase db,
  WeatherCollectLocation location,
) async {
  if (location.id != kSyntheticDefaultWeatherLocationId) {
    return;
  }
  await db.into(db.interestsLocations).insertOnConflictUpdate(
        InterestsLocationsCompanion.insert(
          id: location.id,
          name: location.name,
          latitude: location.lat,
          longitude: location.lon,
          includeWeather: const Value(true),
          includeWeatherAlerts: const Value(true),
        ),
      );
}

/// [InterestsLocations] rows that should receive NWS active-alert collection,
/// or a single synthetic [kSyntheticDefaultWeatherLocationId] when no rows have
/// [InterestsLocation.includeWeather] (same fallback as [resolveWeatherLocationsForCollect]).
///
/// When at least one row has weather enabled, only rows with
/// [InterestsLocation.includeWeatherAlerts] true are included (the list may be
/// empty if every weather-enabled row opts out).
Future<List<WeatherCollectLocation>> resolveWeatherLocationsForActiveAlertsCollect(
  AppDatabase db,
  WeatherLocationConfig defaultLocation,
) async {
  final weatherRows = await (db.select(db.interestsLocations)
        ..where((t) => t.includeWeather.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .get();
  if (weatherRows.isEmpty) {
    return [
      WeatherCollectLocation(
        id: kSyntheticDefaultWeatherLocationId,
        name: defaultLocation.name,
        lat: defaultLocation.latitude,
        lon: defaultLocation.longitude,
      ),
    ];
  }
  return weatherRows
      .where((r) => r.includeWeatherAlerts)
      .map(
        (r) => WeatherCollectLocation(
          id: r.id,
          name: r.name,
          lat: r.latitude,
          lon: r.longitude,
        ),
      )
      .toList();
}
