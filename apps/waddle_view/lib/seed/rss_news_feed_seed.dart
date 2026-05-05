import 'package:drift/drift.dart';

import '../persistence/database.dart';

/// Default feeds from repo `data/news-data-sources.md` (idempotent inserts).
Future<void> ensureDefaultRssNewsFeeds(AppDatabase db) async {
  for (final f in _defaultRssFeeds) {
    final existing =
        await (db.select(db.rssFeedSources)..where((t) => t.id.equals(f.id)))
            .getSingleOrNull();
    if (existing != null) {
      continue;
    }
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: f.id,
            url: f.url,
            category: Value(f.category),
          ),
        );
  }
}

/// (id, url, category) — mirrors `data/news-data-sources.md` at the repo root.
const _defaultRssFeeds = <({String id, String url, String category})>[
  // World News
  (
    id: 'bbc_world',
    url: 'https://feeds.bbci.co.uk/news/world/rss.xml',
    category: 'world',
  ),
  (
    id: 'nbc_world',
    url: 'https://feeds.nbcnews.com/nbcnews/public/news',
    category: 'world',
  ),
  (
    id: 'cnbc_international',
    url: 'https://www.cnbc.com/id/100727362/device/rss/rss.html',
    category: 'world',
  ),
  (
    id: 'abc_international',
    url: 'https://abcnews.go.com/abcnews/internationalheadlines',
    category: 'world',
  ),
  // USA News
  (
    id: 'nbc_usa',
    url: 'https://feeds.nbcnews.com/nbcnews/public/news',
    category: 'usa',
  ),
  (
    id: 'abc_usa',
    url: 'https://abcnews.go.com/abcnews/topstories',
    category: 'usa',
  ),
  (
    id: 'cbs_news',
    url: 'https://www.cbsnews.com/latest/rss/main',
    category: 'usa',
  ),
  (
    id: 'politico',
    url: 'https://www.politico.com/rss/politicopicks.xml',
    category: 'usa',
  ),
  (
    id: 'ny_times',
    url: 'https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml',
    category: 'usa',
  ),
  (
    id: 'washington_times',
    url: 'https://www.washingtontimes.com/rss/headlines/news',
    category: 'usa',
  ),
  (
    id: 'vox',
    url: 'https://www.vox.com/rss/index.xml',
    category: 'usa',
  ),
  (
    id: 'observer',
    url: 'https://observer.com/feed/',
    category: 'usa',
  ),
];
