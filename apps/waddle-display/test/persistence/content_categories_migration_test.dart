import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_display/persistence/content_category_defaults.dart';
import 'package:waddle_display/persistence/database.dart';

import '../helpers/legacy_migration_schema_stubs.dart';

void main() {
  test('v18 to v19 creates content_categories with default rows', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE photos (
  id TEXT NOT NULL PRIMARY KEY,
  category TEXT NOT NULL DEFAULT 'pexels',
  data_provider TEXT NOT NULL DEFAULT 'pexels',
  media_blob_key TEXT NOT NULL,
  photographer_name TEXT NOT NULL,
  photographer_url TEXT NOT NULL,
  pexels_page_url TEXT NOT NULL,
  alt_text TEXT NOT NULL DEFAULT '',
  fetched_at_ms INTEGER NOT NULL
);
''');
    raw.execute('''
CREATE TABLE videos (
  id TEXT NOT NULL PRIMARY KEY,
  category TEXT NOT NULL DEFAULT 'pexels',
  data_provider TEXT NOT NULL DEFAULT 'pexels',
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
      'CREATE INDEX idx_photos_fetched ON photos (fetched_at_ms);',
    );
    raw.execute(
      'CREATE INDEX idx_photos_category ON photos (category);',
    );
    raw.execute(
      'CREATE INDEX idx_videos_fetched ON videos (fetched_at_ms);',
    );
    raw.execute(
      'CREATE INDEX idx_videos_category ON videos (category);',
    );
    raw.execute('PRAGMA user_version = 18;');
    stubCalendarEventsAndBlobMetadataForMigration(raw);

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customStatement('SELECT 1');

    final rows = await db.select(db.contentCategories).get();
    expect(rows.length, kContentCategoryDefaults.length);

    final world = await (db.select(db.contentCategories)
          ..where((t) => t.id.equals('world')))
        .getSingle();
    expect(world.label, 'World news');
    expect(world.materialIconName, 'public');
    expect(world.iconBlobKey, isNull);

    await db.close();
  });
}
