import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_shared/seed/tables/interests_rss_feeds_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('ensureDefaultInterestsRssFeeds inserts all sources once', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultInterestsRssFeeds(db);
    final first = await db.select(db.interestsRssFeeds).get();
    expect(first.length, 83);
    await ensureDefaultInterestsRssFeeds(db);
    final second = await db.select(db.interestsRssFeeds).get();
    expect(second.length, 83);
    final world = second.where((r) => r.category == 'world').length;
    final usa = second.where((r) => r.category == 'usa').length;
    final technology = second.where((r) => r.category == 'technology').length;
    final finance = second.where((r) => r.category == 'finance').length;
    final science = second.where((r) => r.category == 'science').length;
    final travel = second.where((r) => r.category == 'travel').length;
    final wellness = second.where((r) => r.category == 'wellness').length;
    final entertainment =
        second.where((r) => r.category == 'entertainment').length;
    final sports = second.where((r) => r.category == 'sports').length;
    expect(world, 4);
    expect(usa, 8);
    expect(technology, 14);
    expect(finance, 9);
    expect(science, 9);
    expect(travel, 10);
    expect(wellness, 9);
    expect(entertainment, 10);
    expect(sports, 10);
    final hn = await (db.select(db.interestsRssFeeds)
          ..where((t) => t.id.equals('hacker_news')))
        .getSingleOrNull();
    expect(hn, isNotNull);
    expect(hn!.maxArticles, 3);
    await db.close();
  });
}
