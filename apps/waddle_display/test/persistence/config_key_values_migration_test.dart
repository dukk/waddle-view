import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_display/persistence/database.dart';
import 'package:waddle_display/persistence/tables.dart';

import '../helpers/legacy_migration_schema_stubs.dart';

void main() {
  test('v15 to v16 copies curator row and renames kv table', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE dashboard_kv (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
    raw.execute('''
CREATE TABLE curator_settings (
  id TEXT NOT NULL PRIMARY KEY,
  program_duration_seconds INTEGER NOT NULL DEFAULT 180,
  history_depth INTEGER NOT NULL DEFAULT 5
);
''');
    raw.execute(
      "INSERT INTO curator_settings VALUES ('app', 240, 7);",
    );
    raw.execute(
      "INSERT INTO dashboard_kv VALUES ('header.title', 'X');",
    );
    raw.execute('PRAGMA user_version = 15;');
    stubCalendarEventsAndBlobMetadataForMigration(raw);
    stubLegacyScreenDefinitionsForMigration(raw);

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customStatement('SELECT 1');

    final rows = await db.select(db.configKeyValues).get();
    final byKey = {for (final r in rows) r.key: r.value};
    expect(byKey['header.title'], 'X');
    expect(byKey[kCuratorProgramDurationSecondsKvKey], '240');
    expect(byKey[kCuratorHistoryDepthKvKey], '7');

    final tableCheck = raw.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('curator_settings','dashboard_kv','config_key_values') ORDER BY name",
    );
    final names = [for (final r in tableCheck) r['name'] as String];
    expect(names, ['config_key_values']);

    await db.close();
  });
}
