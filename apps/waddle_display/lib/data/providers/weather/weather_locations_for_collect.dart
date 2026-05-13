import 'package:drift/drift.dart' show OrderingTerm;

import 'package:waddle_shared/persistence/database.dart';
import 'weather_provider_extra_config.dart';

/// Enabled [WeatherLocations] rows, or a single synthetic `default` when none.
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
  final rows = await (db.select(db.weatherLocations)
        ..where((t) => t.enabled.equals(true))
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
