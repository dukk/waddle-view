import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/seed/tables/interests_locations_seed.dart';

void main() {
  test('schema 38 to 39 trims retired catalog and repoints weather screen', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE interests_locations (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  include_weather INTEGER NOT NULL DEFAULT 0,
  include_weather_alerts INTEGER NOT NULL DEFAULT 0,
  include_local_news INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute(
        "INSERT INTO interests_locations (id, name, latitude, longitude, category) "
        "VALUES ('salt_lake_city_ut', 'Salt Lake City, UT', 40.76, -111.89, 'north_america')",
      );
      raw.execute(
        "INSERT INTO interests_locations (id, name, latitude, longitude, category) "
        "VALUES ('new_york_ny', 'New York, NY', 40.71, -74.0, 'north_america')",
      );
      raw.execute('''
CREATE TABLE screens (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT,
  screen_type TEXT NOT NULL,
  config_json TEXT NOT NULL DEFAULT '{}',
  min_dwell_seconds INTEGER NOT NULL DEFAULT 10,
  max_dwell_seconds INTEGER NOT NULL DEFAULT 20,
  data_key TEXT,
  min_placements_per_program INTEGER NOT NULL DEFAULT 0,
  max_placements_per_program INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute(
        "INSERT INTO screens (id, label, screen_type, config_json) "
        "VALUES ('weather', 'Weather', 'weather', '{\"locationId\":\"salt_lake_city_ut\"}')",
      );
      raw.execute('PRAGMA user_version = 38');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final slc = await db.customSelect(
      'SELECT id FROM interests_locations WHERE id = ?',
      variables: [Variable<String>('salt_lake_city_ut')],
    ).getSingleOrNull();
    expect(slc, isNull);

    final nyc = await db.customSelect(
      'SELECT name, category FROM interests_locations WHERE id = ?',
      variables: [Variable<String>('new_york_ny')],
    ).getSingle();
    expect(nyc.read<String>('name'), 'New York, NY');
    expect(nyc.read<String>('category'), 'general');

    final catalogCount = await db.customSelect(
      'SELECT COUNT(*) AS c FROM interests_locations '
      'WHERE id IN (${kDefaultWeatherLocationCatalogIds.map((_) => '?').join(', ')})',
      variables: [
        for (final id in kDefaultWeatherLocationCatalogIds) Variable<String>(id),
      ],
    ).getSingle();
    expect(catalogCount.read<int>('c'), 5);

    final screen = await db.customSelect(
      'SELECT config_json FROM screens WHERE id = ?',
      variables: [Variable<String>('weather')],
    ).getSingle();
    expect(screen.read<String>('config_json'), contains('new_york_ny'));
    expect(screen.read<String>('config_json'), isNot(contains('salt_lake_city_ut')));

    await db.close();
  });
}
