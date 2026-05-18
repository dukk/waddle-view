import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/weather_location_category.dart';

void main() {
  test('schema 7 to 8 adds interests_locations.category and seeds world rows', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE interests_locations (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  include_active_weather_alerts INTEGER NOT NULL DEFAULT 1
);
''');
      raw.execute(
        "INSERT INTO interests_locations (id, name, latitude, longitude, enabled) "
        "VALUES ('sea', 'Seattle, WA', 47.6, -122.3, 1)",
      );
      raw.execute('''
CREATE TABLE integrations (
  id TEXT NOT NULL PRIMARY KEY,
  integration_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  base_url TEXT,
  config_json TEXT,
  config_json_schema TEXT,
  example_config_json TEXT
);
''');
      raw.execute('''
CREATE TABLE integration_accounts (
  id TEXT NOT NULL PRIMARY KEY,
  account_type TEXT NOT NULL,
  label TEXT,
  created_at_ms INTEGER NOT NULL
);
''');
      raw.execute('PRAGMA user_version = 7');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final row = await db.customSelect(
      'SELECT category FROM interests_locations WHERE id = ?',
      variables: [Variable<String>('sea')],
    ).getSingle();
    expect(row.read<String>('category'), kWeatherLocationRegionNorthAmerica);

    final london = await db.customSelect(
      'SELECT include_weather, category FROM interests_locations WHERE id = ?',
      variables: [Variable<String>('london_gb')],
    ).getSingleOrNull();
    expect(london, isNotNull);
    expect(london!.read<String>('category'), kWeatherLocationRegionEurope);
    expect(london.read<int>('include_weather'), 0);

    await db.close();
  });
}
