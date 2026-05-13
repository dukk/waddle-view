import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/legacy_migration_schema_stubs.dart';

void main() {
  test(
      'v29 -> v30 adds consecutive_failures and next_retry_at to rss_feed_sources',
      () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE rss_feed_sources (
  id TEXT NOT NULL PRIMARY KEY,
  url TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  poll_seconds INTEGER NOT NULL DEFAULT 3600,
  max_articles INTEGER NOT NULL DEFAULT 3,
  enabled INTEGER NOT NULL DEFAULT 1,
  last_fetched_at INTEGER,
  title TEXT
);
''');
    raw.execute(
      "INSERT INTO rss_feed_sources (id, url) "
      "VALUES ('preexisting', 'http://example.local/feed.xml');",
    );
    raw.execute('PRAGMA user_version = 29;');
    stubContentCategoriesForMigration(raw);
    stubCalendarEventsAndBlobMetadataForMigration(raw);
    stubLegacyScreenDefinitionsForMigration(raw);

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customStatement('SELECT 1');

    final cols =
        await db.customSelect('PRAGMA table_info(rss_feed_sources);').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names.contains('consecutive_failures'), isTrue);
    expect(names.contains('next_retry_at'), isTrue);

    final row = await (db.select(db.rssFeedSources)
          ..where((t) => t.id.equals('preexisting')))
        .getSingle();
    expect(row.consecutiveFailures, 0,
        reason: 'existing rows default to 0 failures');
    expect(row.nextRetryAt, null,
        reason: 'existing rows have no pending retry');

    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'fresh',
            url: 'http://example.local/feed2.xml',
            consecutiveFailures: const Value(2),
            nextRetryAt: Value(DateTime.fromMillisecondsSinceEpoch(1000)),
          ),
        );
    final fresh = await (db.select(db.rssFeedSources)
          ..where((t) => t.id.equals('fresh')))
        .getSingle();
    expect(fresh.consecutiveFailures, 2);
    expect(fresh.nextRetryAt?.millisecondsSinceEpoch, 1000);

    await db.close();
  });
}
