import 'package:drift/drift.dart' show OrderingTerm;

import 'package:waddle_shared/persistence/database.dart';
import 'weather_provider_extra_config.dart';

/// [InterestsLocations] rows with [InterestsLocation.includeWeather], or a
/// single synthetic `default` when none.
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
  AppDatabase db,
  WeatherLocationConfig defaultLocation,
) async {
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
  return [
    WeatherCollectLocation(
      id: 'default',
      name: defaultLocation.name,
      lat: defaultLocation.latitude,
      lon: defaultLocation.longitude,
    ),
  ];
}

/// [InterestsLocations] rows that should receive NWS active-alert collection,
/// or a single synthetic `default` when no rows have [InterestsLocation.includeWeather]
/// (same fallback as [resolveWeatherLocationsForCollect]).
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
        id: 'default',
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
