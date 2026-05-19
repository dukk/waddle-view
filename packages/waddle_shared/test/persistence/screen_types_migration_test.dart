import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 26 to 27 extracts screen_types and trims screens', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE screens (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  screen_type TEXT NOT NULL,
  config_json TEXT NOT NULL DEFAULT '{}',
  config_json_schema TEXT,
  example_config_json TEXT,
  min_dwell_seconds INTEGER NOT NULL DEFAULT 8,
  max_dwell_seconds INTEGER NOT NULL DEFAULT 15,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  min_gap_between_shows_seconds INTEGER NOT NULL DEFAULT 0,
  min_placements_per_program INTEGER NOT NULL DEFAULT 0,
  max_placements_per_program INTEGER,
  data_key TEXT NOT NULL DEFAULT ''
);
''');
      raw.execute(
        "INSERT INTO screens "
        "(id, label, screen_type, config_json, config_json_schema, example_config_json) "
        "VALUES ('weather', 'Weather slide', 'weather', '{}', "
        "'{\"type\":\"object\"}', '{\"city\":\"Boston\"}')",
      );
      raw.execute('PRAGMA user_version = 26');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final typeRows = await db.customSelect(
      'SELECT screen_type, label, config_json_schema FROM screen_types '
      'WHERE screen_type = ?',
      variables: [const Variable<String>('weather')],
    ).getSingle();
    expect(typeRows.read<String>('label'), 'Weather');
    expect(typeRows.read<String?>('config_json_schema'), contains('object'));

    final screenColumns = await db.customSelect(
      'PRAGMA table_info(screens)',
    ).get();
    final names = screenColumns.map((c) => c.read<String>('name')).toSet();
    expect(names.contains('config_json_schema'), isFalse);
    expect(names.contains('example_config_json'), isFalse);

    final screen = await db.customSelect(
      'SELECT id, label, screen_type, config_json FROM screens WHERE id = ?',
      variables: [const Variable<String>('weather')],
    ).getSingle();
    expect(screen.read<String>('id'), 'weather');
    expect(screen.read<String>('screen_type'), 'weather');

    await db.close();
  });
}
