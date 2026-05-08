import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/data/seed/tables/rss_feed_sources_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('ensureDefaultRssNewsFeeds inserts all sources once', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultRssNewsFeeds(db);
    final first = await db.select(db.rssFeedSources).get();
    expect(first.length, 44);
    await ensureDefaultRssNewsFeeds(db);
    final second = await db.select(db.rssFeedSources).get();
    expect(second.length, 44);
    final world = second.where((r) => r.category == 'world').length;
    final usa = second.where((r) => r.category == 'usa').length;
    final technology = second.where((r) => r.category == 'technology').length;
    final finance = second.where((r) => r.category == 'finance').length;
    final science = second.where((r) => r.category == 'science').length;
    expect(world, 4);
    expect(usa, 8);
    expect(technology, 14);
    expect(finance, 9);
    expect(science, 9);
    final hn = await (db.select(db.rssFeedSources)
          ..where((t) => t.id.equals('hacker_news')))
        .getSingleOrNull();
    expect(hn, isNotNull);
    expect(hn!.maxArticles, 3);
    await db.close();
  });
}
