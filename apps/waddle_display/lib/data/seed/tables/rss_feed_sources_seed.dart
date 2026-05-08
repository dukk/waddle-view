import 'package:drift/drift.dart';

import '../../persistence/database.dart';

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
            maxArticles: const Value(3),
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
  // Technology
  (
    id: 'hacker_news',
    url: 'https://news.ycombinator.com/rss',
    category: 'technology',
  ),
  (
    id: 'wired',
    url: 'https://www.wired.com/feed/rss',
    category: 'technology',
  ),
  (
    id: 'slashdot',
    url: 'https://rss.slashdot.org/Slashdot/slashdotMain',
    category: 'technology',
  ),
  (
    id: 'the_verge',
    url: 'https://www.theverge.com/rss/index.xml',
    category: 'technology',
  ),
  (
    id: 'medium_technology',
    url: 'https://medium.com/feed/tag/technology',
    category: 'technology',
  ),
  (
    id: 'techcrunch',
    url: 'https://techcrunch.com/feed/',
    category: 'technology',
  ),
  (
    id: 'mashable',
    url: 'https://mashable.com/feed/',
    category: 'technology',
  ),
  (
    id: 'engadget',
    url: 'https://www.engadget.com/rss.xml',
    category: 'technology',
  ),
  (
    id: 'readwrite',
    url: 'https://readwrite.com/feed/',
    category: 'technology',
  ),
  (
    id: 'the_next_web',
    url: 'https://thenextweb.com/feed/',
    category: 'technology',
  ),
  (
    id: 'mac_rumors',
    url: 'https://feeds.macrumors.com/MacRumors-All',
    category: 'technology',
  ),
  (
    id: 'android_police',
    url: 'https://www.androidpolice.com/feed/',
    category: 'technology',
  ),
  (
    id: 'techradar',
    url: 'https://www.techradar.com/rss',
    category: 'technology',
  ),
  (
    id: 'cnet',
    url: 'https://www.cnet.com/rss/news/',
    category: 'technology',
  ),
  // Finance
  (
    id: 'wired_business',
    url: 'https://www.wired.com/feed/category/business/latest/rss',
    category: 'finance',
  ),
  (
    id: 'medium_business',
    url: 'https://medium.com/feed/tag/business',
    category: 'finance',
  ),
  (
    id: 'economist_finance',
    url: 'https://www.economist.com/finance-and-economics/rss.xml',
    category: 'finance',
  ),
  (
    id: 'marketwatch',
    url: 'https://www.marketwatch.com/rss/topstories',
    category: 'finance',
  ),
  (
    id: 'wsj_markets',
    url: 'https://feeds.content.dowjones.io/public/rss/RSSMarketsMain',
    category: 'finance',
  ),
  (
    id: 'forbes_money',
    url: 'https://www.forbes.com/business/feed/',
    category: 'finance',
  ),
  (
    id: 'yahoo_finance',
    url: 'https://finance.yahoo.com/news/rss/',
    category: 'finance',
  ),
  (
    id: 'bloomberg_markets',
    url: 'https://feeds.bloomberg.com/markets/news.rss',
    category: 'finance',
  ),
  (
    id: 'motley_fool',
    url: 'https://www.fool.com/feeds/index.aspx',
    category: 'finance',
  ),
  // Science
  (
    id: 'nature',
    url: 'https://www.nature.com/nature.rss',
    category: 'science',
  ),
  (
    id: 'medium_science',
    url: 'https://medium.com/feed/tag/science',
    category: 'science',
  ),
  (
    id: 'scientific_american',
    url: 'https://feeds.feedburner.com/ScientificAmerican-Global',
    category: 'science',
  ),
  (
    id: 'phys_org',
    url: 'https://phys.org/rss-feed/',
    category: 'science',
  ),
  (
    id: 'quanta_magazine',
    url: 'https://www.quantamagazine.org/feed/',
    category: 'science',
  ),
  (
    id: 'smarter_every_day',
    url:
        'https://www.youtube.com/feeds/videos.xml?channel_id=UC6107grRI4m0o2-emgoDnAA',
    category: 'science',
  ),
  (
    id: 'veritasium',
    url:
        'https://www.youtube.com/feeds/videos.xml?channel_id=UCHnyfMqiRRG1u-2MsSQLbXA',
    category: 'science',
  ),
  (
    id: 'scishow',
    url:
        'https://www.youtube.com/feeds/videos.xml?channel_id=UCZYTClx2T1of7BRZ86-8fow',
    category: 'science',
  ),
  (
    id: 'wired_science',
    url: 'https://www.wired.com/feed/category/science/latest/rss',
    category: 'science',
  ),
];
