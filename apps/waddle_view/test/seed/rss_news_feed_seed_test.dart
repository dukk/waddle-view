import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/seed/rss_news_feed_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('ensureDefaultRssNewsFeeds inserts all sources once', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultRssNewsFeeds(db);
    final first = await db.select(db.rssFeedSources).get();
    expect(first.length, 12);
    await ensureDefaultRssNewsFeeds(db);
    final second = await db.select(db.rssFeedSources).get();
    expect(second.length, 12);
    final world = second.where((r) => r.category == 'world').length;
    final usa = second.where((r) => r.category == 'usa').length;
    expect(world, 4);
    expect(usa, 8);
    await db.close();
  });
}
