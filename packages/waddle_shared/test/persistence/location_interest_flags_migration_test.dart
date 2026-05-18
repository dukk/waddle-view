import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 8 to 9 renames location flags and adds include_local_news', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE interests_locations (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  enabled INTEGER NOT NULL DEFAULT 1,
  include_active_weather_alerts INTEGER NOT NULL DEFAULT 1
);
''');
      raw.execute(
        "INSERT INTO interests_locations (id, name, latitude, longitude, enabled, "
        "include_active_weather_alerts) "
        "VALUES ('sea', 'Seattle, WA', 47.6, -122.3, 1, 0)",
      );
      raw.execute('PRAGMA user_version = 8');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final row = await db.customSelect(
      'SELECT include_weather, include_weather_alerts, include_local_news '
      'FROM interests_locations WHERE id = ?',
      variables: [Variable<String>('sea')],
    ).getSingle();
    expect(row.read<int>('include_weather'), 1);
    expect(row.read<int>('include_weather_alerts'), 0);
    expect(row.read<int>('include_local_news'), 0);

    await db.close();
  });
}
