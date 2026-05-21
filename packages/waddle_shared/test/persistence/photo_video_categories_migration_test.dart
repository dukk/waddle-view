import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 37 to 38 adds photo/video_categories and backfills', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('PRAGMA user_version = 37');
      raw.execute('''
CREATE TABLE curator_categories (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  material_icon_name TEXT,
  icon_blob_key TEXT
)
''');
      raw.execute('''
CREATE TABLE photos (
  id TEXT NOT NULL PRIMARY KEY,
  category TEXT NOT NULL DEFAULT 'pexels',
  data_provider TEXT NOT NULL DEFAULT 'pexels',
  media_blob_key TEXT NOT NULL,
  photographer_name TEXT NOT NULL,
  photographer_url TEXT NOT NULL,
  page_url TEXT NOT NULL,
  alt_text TEXT NOT NULL DEFAULT '',
  fetched_at_ms INTEGER NOT NULL,
  suppressed INTEGER NOT NULL DEFAULT 0
)
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
  fetched_at_ms INTEGER NOT NULL,
  suppressed INTEGER NOT NULL DEFAULT 0
)
''');
      raw.execute(
        "INSERT INTO curator_categories (id, label) VALUES ('fam', 'Family')",
      );
      raw.execute(
        "INSERT INTO photos (id, category, data_provider, media_blob_key, "
        "photographer_name, photographer_url, page_url, fetched_at_ms) "
        "VALUES ('p1', 'fam', 'photo_onedrive', 'b1', '', '', '', 0)",
      );
      raw.execute(
        "INSERT INTO videos (id, category, data_provider, media_blob_key, "
        "photographer_name, photographer_url, pexels_page_url, "
        "duration_seconds, fetched_at_ms) "
        "VALUES ('v1', 'fam', 'video_onedrive', 'b2', '', '', '', 1, 0)",
      );
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final photoJunction = await db.customSelect(
      'SELECT photo_id, category_id FROM photo_categories',
    ).get();
    expect(photoJunction.length, 1);
    expect(photoJunction.single.read<String>('photo_id'), 'p1');
    expect(photoJunction.single.read<String>('category_id'), 'fam');

    final videoJunction = await db.customSelect(
      'SELECT video_id, category_id FROM video_categories',
    ).get();
    expect(videoJunction.length, 1);
    expect(videoJunction.single.read<String>('video_id'), 'v1');

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);

    await db.close();
  });
}
