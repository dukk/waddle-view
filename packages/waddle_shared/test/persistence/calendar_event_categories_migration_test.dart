import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 24 to 25 adds calendar_event_categories and backfills', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('PRAGMA user_version = 24');
      raw.execute('''
CREATE TABLE content_categories (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  material_icon_name TEXT,
  icon_blob_key TEXT
)
''');
      raw.execute('''
CREATE TABLE calendar_events (
  id TEXT NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  all_day INTEGER NOT NULL DEFAULT 0,
  location TEXT,
  description TEXT,
  source TEXT NOT NULL DEFAULT 'local',
  external_id TEXT,
  ical_uid TEXT,
  category_id TEXT,
  updated_at_ms INTEGER NOT NULL,
  FOREIGN KEY (category_id) REFERENCES content_categories(id)
)
''');
      raw.execute(
        "INSERT INTO content_categories (id, label) VALUES ('work', 'Work')",
      );
      raw.execute(
        "INSERT INTO calendar_events "
        "(id, title, start_ms, end_ms, category_id, updated_at_ms) "
        "VALUES ('e1', 'Meet', 0, 1, 'work', 0)",
      );
    });
    final connection = DatabaseConnection(
      executor,
      closeStreamsSynchronously: true,
    );

    final db = AppDatabase(connection);
    await db.customStatement('SELECT 1');

    final junction = await db.customSelect(
      'SELECT event_id, category_id FROM calendar_event_categories',
    ).get();
    expect(junction.length, 1);
    expect(junction.single.read<String>('event_id'), 'e1');
    expect(junction.single.read<String>('category_id'), 'work');

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);

    await db.close();
  });
}
