import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_display/persistence/database.dart';
import 'package:waddle_display/persistence/tables.dart';

import '../helpers/legacy_migration_schema_stubs.dart';

void main() {
  test('v17 to v18 renames media tables and adds data_provider', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE pexels_photos (
  id TEXT NOT NULL PRIMARY KEY,
  category TEXT NOT NULL DEFAULT 'pexels',
  media_blob_key TEXT NOT NULL,
  photographer_name TEXT NOT NULL,
  photographer_url TEXT NOT NULL,
  pexels_page_url TEXT NOT NULL,
  alt_text TEXT NOT NULL DEFAULT '',
  fetched_at_ms INTEGER NOT NULL
);
''');
    raw.execute(
      "INSERT INTO pexels_photos "
      "VALUES ('p1','nature','blob/k','A','u','u2','',1000);",
    );
    raw.execute('''
CREATE TABLE pexels_videos (
  id TEXT NOT NULL PRIMARY KEY,
  category TEXT NOT NULL DEFAULT 'pexels',
  media_blob_key TEXT NOT NULL,
  photographer_name TEXT NOT NULL,
  photographer_url TEXT NOT NULL,
  pexels_page_url TEXT NOT NULL,
  alt_text TEXT NOT NULL DEFAULT '',
  duration_seconds INTEGER NOT NULL,
  fetched_at_ms INTEGER NOT NULL
);
''');
    raw.execute(
      "INSERT INTO pexels_videos "
      "VALUES ('v1','nature','blob/v','A','u','u2','',30,2000);",
    );
    raw.execute(
      'CREATE INDEX idx_pexels_photos_fetched ON pexels_photos (fetched_at_ms);',
    );
    raw.execute(
      'CREATE INDEX idx_pexels_photos_category ON pexels_photos (category);',
    );
    raw.execute(
      'CREATE INDEX idx_pexels_videos_fetched ON pexels_videos (fetched_at_ms);',
    );
    raw.execute(
      'CREATE INDEX idx_pexels_videos_category ON pexels_videos (category);',
    );
    raw.execute('PRAGMA user_version = 17;');
    stubCalendarEventsAndBlobMetadataForMigration(raw);
    stubLegacyScreenDefinitionsForMigration(raw);

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customStatement('SELECT 1');

    final photo =
        await (db.select(db.photos)..where((t) => t.id.equals('p1')))
            .getSingle();
    expect(photo.dataProvider, kMediaDataProviderPexels);
    expect(photo.mediaBlobKey, 'blob/k');

    final video =
        await (db.select(db.videos)..where((t) => t.id.equals('v1')))
            .getSingle();
    expect(video.dataProvider, kMediaDataProviderPexels);
    expect(video.durationSeconds, 30);

    final legacy = raw.select(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('pexels_photos','pexels_videos')",
    );
    expect(legacy, isEmpty);

    await db.close();
  });
}
