import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 26 to 27 extracts overlay_types and trims overlays', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
CREATE TABLE overlays (
  id TEXT NOT NULL PRIMARY KEY,
  overlay_type TEXT NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  config_json TEXT NOT NULL DEFAULT '{}',
  config_json_schema TEXT
);
''');
        raw.execute(
          "INSERT INTO overlays "
          "(id, overlay_type, label, config_json, config_json_schema) "
          "VALUES ('default_birthday', 'birthday_confetti', 'Birthday', '{}', "
          "'{\"type\":\"object\"}')",
        );
        raw.execute('PRAGMA user_version = 26');
      },
    );
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final typeRows = await db
        .customSelect(
          'SELECT overlay_type, label FROM overlay_types '
          'WHERE overlay_type = ?',
          variables: [const Variable<String>('birthday_confetti')],
        )
        .getSingle();
    expect(typeRows.read<String>('label'), 'Birthday confetti');

    final columns = await db.customSelect('PRAGMA table_info(overlays)').get();
    final names = columns.map((c) => c.read<String>('name')).toSet();
    expect(names.contains('config_json_schema'), isFalse);
    expect(names, containsAll(['id', 'overlay_type', 'label', 'config_json']));

    final overlay = await db
        .customSelect(
          'SELECT id, overlay_type FROM overlays WHERE id = ?',
          variables: [const Variable<String>('default_birthday')],
        )
        .getSingle();
    expect(overlay.read<String>('overlay_type'), 'birthday_confetti');

    await db.close();
  });

  test('onCreate ensures overlay_types table', () async {
    final executor = NativeDatabase.memory();
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'overlay_types'",
        )
        .get();
    expect(tables.length, 1);
    await db.close();
  });
}
