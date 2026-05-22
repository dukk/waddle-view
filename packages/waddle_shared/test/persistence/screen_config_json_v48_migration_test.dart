import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 47 to 48 migrates screen config_json on upgrade', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
CREATE TABLE content_categories (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  material_icon_name TEXT NOT NULL DEFAULT 'label_outline'
);
''');
        raw.execute(
          "INSERT INTO content_categories (id, label) VALUES ('work', 'Work')",
        );
        raw.execute('''
CREATE TABLE screens (
  id TEXT NOT NULL PRIMARY KEY,
  screen_type TEXT NOT NULL,
  label TEXT NOT NULL,
  description TEXT,
  config_json TEXT NOT NULL DEFAULT '{}',
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
          "INSERT INTO screens (id, screen_type, label, config_json) "
          "VALUES ('cal', 'calendar_month', 'Calendar', "
          "'{\"categoryId\":\"work\"}')",
        );
        raw.execute('PRAGMA user_version = 47');
      },
    );
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final row = await db
        .customSelect(
          'SELECT config_json FROM screens WHERE id = ?',
          variables: [Variable<String>('cal')],
        )
        .getSingle();
    final config =
        jsonDecode(row.read<String>('config_json')) as Map<String, dynamic>;
    expect(config['categoryId'], isNull);
    expect(config['categoryName'], 'Work');

    expect(db.schemaVersion, 48);
    await db.close();
  });
}
