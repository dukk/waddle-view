import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/data/providers/weather/weather_locations_for_collect.dart';
import 'package:waddle_display/data/providers/weather/weather_provider_extra_config.dart';
import 'package:waddle_display/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test('resolveWeatherLocationsForCollect uses default when no enabled rows',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    const def = WeatherLocationConfig(
      name: 'Fallback City',
      latitude: 12.5,
      longitude: -34.25,
    );
    final list = await resolveWeatherLocationsForCollect(db, def);
    expect(list, hasLength(1));
    expect(list.single.id, 'default');
    expect(list.single.name, 'Fallback City');
    expect(list.single.lat, 12.5);
    expect(list.single.lon, -34.25);
    await db.close();
  });

  test('resolveWeatherLocationsForCollect maps enabled rows in id order', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.weatherLocations).insert(
          WeatherLocationsCompanion.insert(
            id: 'b',
            name: 'Beta',
            latitude: 2,
            longitude: 2,
            enabled: const Value(true),
          ),
        );
    await db.into(db.weatherLocations).insert(
          WeatherLocationsCompanion.insert(
            id: 'a',
            name: 'Alpha',
            latitude: 1,
            longitude: -1,
            enabled: const Value(true),
          ),
        );
    await db.into(db.weatherLocations).insert(
          WeatherLocationsCompanion.insert(
            id: 'off',
            name: 'Off',
            latitude: 0,
            longitude: 0,
            enabled: const Value(false),
          ),
        );
    const def = WeatherLocationConfig(
      name: 'Ignored',
      latitude: 0,
      longitude: 0,
    );
    final list = await resolveWeatherLocationsForCollect(db, def);
    expect(list.map((e) => e.id).toList(), ['a', 'b']);
    expect(list.first.name, 'Alpha');
    await db.close();
  });
}
