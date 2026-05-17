import 'package:drift/drift.dart';

import 'package:waddle_shared/persistence/database.dart';

/// Default feeds from repo `data/news-data-sources.md` (idempotent inserts).
Future<void> ensureDefaultInterestsRssFeeds(AppDatabase db) async {
  for (final f in _defaultRssFeeds) {
    final existing = await (db.select(
      db.interestsRssFeeds,
    )..where((t) => t.id.equals(f.id))).getSingleOrNull();
    if (existing != null) {
      continue;
    }
    await db
        .into(db.interestsRssFeeds)
        .insert(
          InterestsRssFeedsCompanion.insert(
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
  (id: 'vox', url: 'https://www.vox.com/rss/index.xml', category: 'usa'),
  (id: 'observer', url: 'https://observer.com/feed/', category: 'usa'),
  // Technology
  (
    id: 'hacker_news',
    url: 'https://news.ycombinator.com/rss',
    category: 'technology',
  ),
  (id: 'wired', url: 'https://www.wired.com/feed/rss', category: 'technology'),
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
  (id: 'mashable', url: 'https://mashable.com/feed/', category: 'technology'),
  (
    id: 'engadget',
    url: 'https://www.engadget.com/rss.xml',
    category: 'technology',
  ),
  (id: 'readwrite', url: 'https://readwrite.com/feed/', category: 'technology'),
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
  (id: 'cnet', url: 'https://www.cnet.com/rss/news/', category: 'technology'),
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
  (id: 'nature', url: 'https://www.nature.com/nature.rss', category: 'science'),
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
  (id: 'phys_org', url: 'https://phys.org/rss-feed/', category: 'science'),
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
  // Travel & Lifestyle
  (
    id: 'cn_traveler',
    url: 'https://www.cntraveler.com/feed/rss',
    category: 'travel',
  ),
  (
    id: 'adventure_journal',
    url: 'https://www.adventure-journal.com/feed/',
    category: 'travel',
  ),
  (
    id: 'two_monkeys_travel',
    url: 'https://twomonkeystravelgroup.com/feed/',
    category: 'travel',
  ),
  (
    id: 'adventures_with_nie_nie',
    url: 'https://adventureswithnienie.com/feed/',
    category: 'travel',
  ),
  (
    id: 'flight_mate',
    url: 'https://flightmateza.co.za/feed/',
    category: 'travel',
  ),
  (
    id: 'nomad_experiment',
    url: 'https://www.thenomadexperiment.com/feed/',
    category: 'travel',
  ),
  (
    id: 'nomadic_matt',
    url: 'https://www.nomadicmatt.com/feed/',
    category: 'travel',
  ),
  (
    id: 'travel_to_blank',
    url: 'https://traveltoblank.com/feed/',
    category: 'travel',
  ),
  (
    id: 'via_travelers',
    url: 'https://feeds.feedburner.com/viatravelers/xgwz',
    category: 'travel',
  ),
  (
    id: 'rogue_trippers',
    url: 'https://roguetrippers.com/feed/',
    category: 'travel',
  ),
  // Health & Wellness
  (
    id: 'running_on_real_food',
    url: 'https://runningonrealfood.com/feed/',
    category: 'wellness',
  ),
  (
    id: 'wellness_impact',
    url: 'https://www.wellnessimpact.org/feed/',
    category: 'wellness',
  ),
  (
    id: 'nhs_news',
    url: 'https://www.england.nhs.uk/feed/',
    category: 'wellness',
  ),
  (
    id: 'myfitnesspal_blog',
    url: 'https://blog.myfitnesspal.com/feed/',
    category: 'wellness',
  ),
  (
    id: 'npr_health',
    url: 'https://feeds.npr.org/1128/rss.xml',
    category: 'wellness',
  ),
  (
    id: 'mindful_momma',
    url: 'https://mindfulmomma.com/feed/',
    category: 'wellness',
  ),
  (
    id: 'love_sweat_fitness',
    url: 'https://lovesweatfitness.com/blogs/news.atom',
    category: 'wellness',
  ),
  (
    id: 'yoga_with_adriene',
    url: 'https://yogawithadriene.com/blog/feed/',
    category: 'wellness',
  ),
  (
    id: 'mellowed_wellness',
    url: 'https://mellowed.com/category/health-wellness/feed/',
    category: 'wellness',
  ),
  // Entertainment & Pop Culture
  (
    id: 'celebrity_insider',
    url: 'https://celebrityinsider.org/feed/',
    category: 'entertainment',
  ),
  (id: 'variety', url: 'https://variety.com/feed/', category: 'entertainment'),
  (
    id: 'rolling_stone_music_news',
    url: 'https://www.rollingstone.com/music/music-news/feed/',
    category: 'entertainment',
  ),
  (
    id: 'billboard',
    url: 'https://www.billboard.com/feed/',
    category: 'entertainment',
  ),
  (
    id: 'the_shade_room',
    url: 'https://theshaderoom.com/feed/',
    category: 'entertainment',
  ),
  (
    id: 'e_online_topstories',
    url: 'https://www.eonline.com/syndication/feeds/rssfeeds/topstories',
    category: 'entertainment',
  ),
  (
    id: 'indiewire',
    url: 'https://www.indiewire.com/feed/',
    category: 'entertainment',
  ),
  (
    id: 'hollywood_life',
    url: 'https://hollywoodlife.com/feed/',
    category: 'entertainment',
  ),
  (
    id: 'deadline',
    url: 'https://deadline.com/feed/',
    category: 'entertainment',
  ),
  (id: 'cirrkus', url: 'https://cirrkus.com/feed/', category: 'entertainment'),
  // Sports
  (
    id: 'bbc_sport',
    url: 'https://feeds.bbci.co.uk/sport/rss.xml',
    category: 'sports',
  ),
  (
    id: 'la_times_sports',
    url: 'https://www.latimes.com/sports.rss',
    category: 'sports',
  ),
  (
    id: 'boxing_news_online',
    url: 'https://boxingnewsonline.net/feed/',
    category: 'sports',
  ),
  (
    id: 'smh_sport',
    url: 'https://www.smh.com.au/rss/sport.xml',
    category: 'sports',
  ),
  (
    id: 'washington_times_sports',
    url: 'https://www.washingtontimes.com/rss/headlines/sports/',
    category: 'sports',
  ),
  (
    id: 'boston_sports',
    url: 'https://www.boston.com/category/sports/feed/',
    category: 'sports',
  ),
  (
    id: 'espn_news',
    url: 'https://www.espn.com/espn/rss/news',
    category: 'sports',
  ),
  (
    id: 'cbs_sports_headlines',
    url: 'https://www.cbssports.com/rss/headlines/',
    category: 'sports',
  ),
  (
    id: 'essentially_sports',
    url: 'https://www.essentiallysports.com/feed/',
    category: 'sports',
  ),
  (
    id: 'fox_sports',
    url:
        'https://api.foxsports.com/v2/content/optimized-rss?partnerKey=MB0Wehpmuj2lUhuRhQaafhBjAJqaPU244mlTDK1i&size=30',
    category: 'sports',
  ),
];
