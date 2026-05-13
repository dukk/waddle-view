import 'package:test/test.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/legacy_migration_schema_stubs.dart';

void main() {
  test('v23 to v24 adds pixel_width and pixel_height to blob_metadata', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE blob_metadata (
  blob_key TEXT NOT NULL PRIMARY KEY,
  sha256 TEXT NOT NULL,
  relative_path TEXT NOT NULL,
  bytes INTEGER NOT NULL,
  mime_type TEXT,
  captured_at INTEGER NOT NULL
);
''');
    raw.execute('PRAGMA user_version = 23;');
    stubContentCategoriesForMigration(raw);
    stubCalendarEventsAndBlobMetadataForMigration(raw);
    stubLegacyScreenDefinitionsForMigration(raw);

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customStatement('SELECT 1');

    final cols = await db.customSelect('PRAGMA table_info(blob_metadata);').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names.contains('pixel_width'), isTrue);
    expect(names.contains('pixel_height'), isTrue);

    await db.close();
  });
}
