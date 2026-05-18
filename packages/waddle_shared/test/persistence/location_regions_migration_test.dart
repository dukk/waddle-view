import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/weather_location_category.dart';

void main() {
  test('schema 10 to 11 refreshes location regions and adds catalog cities', () async {
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
        "VALUES ('new_york_ny', 'New York, NY', 40.7, -74.0, 'united_states')",
      );
      raw.execute('PRAGMA user_version = 10');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final nyc = await db.customSelect(
      'SELECT category FROM interests_locations WHERE id = ?',
      variables: [Variable<String>('new_york_ny')],
    ).getSingle();
    expect(nyc.read<String>('category'), kWeatherLocationRegionNorthAmerica);

    final auckland = await db.customSelect(
      'SELECT category FROM interests_locations WHERE id = ?',
      variables: [Variable<String>('auckland_nz')],
    ).getSingleOrNull();
    expect(auckland, isNotNull);
    expect(auckland!.read<String>('category'), kWeatherLocationRegionOceania);

    await db.close();
  });
}
