import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/legacy_migration_schema_stubs.dart';

void main() {
  test('v28 → v29 adds include_active_weather_alerts with default true', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE weather_locations (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1
);
''');
    raw.execute(
      "INSERT INTO weather_locations (id, name, latitude, longitude) "
      "VALUES ('x', 'X', 0, 0);",
    );
    raw.execute('PRAGMA user_version = 28;');
    stubContentCategoriesForMigration(raw);
    stubCalendarEventsAndBlobMetadataForMigration(raw);
    stubLegacyScreenDefinitionsForMigration(raw);

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customStatement('SELECT 1');

    final cols =
        await db.customSelect('PRAGMA table_info(weather_locations);').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names.contains('include_active_weather_alerts'), isTrue);

    final loc = await (db.select(db.weatherLocations)
          ..where((t) => t.id.equals('x')))
        .getSingle();
    expect(loc.includeActiveWeatherAlerts, isTrue);

    await db.close();
  });
}
