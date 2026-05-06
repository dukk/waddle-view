import 'package:drift/drift.dart';

import '../persistence/database.dart';
import 'curator_read_port.dart';
import 'ticker_news_candidate.dart';

class DriftCuratorReadPort implements CuratorReadPort {
  DriftCuratorReadPort(this._db);

  final AppDatabase _db;

  @override
  Future<Map<String, String>> loadKeyValuesForCuration() async {
    final rows = await _db.select(_db.configKeyValues).get();
    return {for (final r in rows) r.key: r.value};
  }

  @override
  Future<List<TickerNewsCandidate>> loadNewsCandidatesForTicker() async {
    final articles = await (_db.select(
      _db.rssArticles,
    )..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])).get();
    if (articles.isEmpty) {
      return const [];
    }
    final feeds = await _db.select(_db.rssFeedSources).get();
    final feedById = {for (final f in feeds) f.id: f};
    return [
      for (final a in articles)
        TickerNewsCandidate(
          feedId: a.feedId,
          feedName: _tickerLabelForFeed(feedById[a.feedId]),
          title: a.title,
          summary: a.summary,
          publishedAtMs: a.publishedAt.millisecondsSinceEpoch,
        ),
    ];
  }

  String _tickerLabelForFeed(RssFeedSource? feed) {
    if (feed == null) {
      return 'general';
    }
    final t = feed.title?.trim() ?? '';
    if (t.isNotEmpty) {
      return t;
    }
    return feed.category;
  }
}
