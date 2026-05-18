import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

void main() {
  test('schema 11 to 12 renames rss_articles to news and adds facebook sources',
      () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE rss_articles (
  id TEXT NOT NULL PRIMARY KEY,
  feed_id TEXT NOT NULL,
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
      raw.execute(
        "INSERT INTO rss_articles (id, feed_id, guid, title, link, published_at, fetched_at) "
        "VALUES ('a1', 'bbc', 'g1', 'Headline', 'https://example.com/1', 1000, 2000)",
      );
      raw.execute('PRAGMA user_version = 11');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final rows = await db.customSelect('SELECT * FROM news').get();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.read<String>('source_id'), 'bbc');
    expect(row.read<String>('source_type'), kNewsSourceTypeRss);
    expect(row.read<String>('title'), 'Headline');

    final fbTable = await db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type='table' "
          "AND name='interests_facebook_sources' LIMIT 1",
        )
        .getSingleOrNull();
    expect(fbTable, isNotNull);
    await db.close();
  });
}
