import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 13 to 14 adds twitter and linkedin source tables', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE news (
  id TEXT NOT NULL PRIMARY KEY,
  source_type TEXT NOT NULL,
  source_id TEXT NOT NULL,
  guid TEXT NOT NULL,
  title TEXT NOT NULL,
  link TEXT NOT NULL,
  summary TEXT,
  published_at INTEGER NOT NULL,
  fetched_at INTEGER NOT NULL,
  image_blob_key TEXT,
  suppressed INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute('''
CREATE TABLE interests_facebook_sources (
  id TEXT NOT NULL PRIMARY KEY,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  poll_seconds INTEGER NOT NULL DEFAULT 3600,
  max_articles INTEGER NOT NULL DEFAULT 3,
  enabled INTEGER NOT NULL DEFAULT 1,
  last_fetched_at INTEGER,
  title TEXT,
  consecutive_failures INTEGER NOT NULL DEFAULT 0,
  next_retry_at INTEGER
);
''');
      raw.execute('PRAGMA user_version = 13');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    for (final name in ['interests_twitter_sources', 'interests_linkedin_sources']) {
      final row = await db
          .customSelect(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='$name' LIMIT 1",
          )
          .getSingleOrNull();
      expect(row, isNotNull);
    }
    await db.close();
  });
}
