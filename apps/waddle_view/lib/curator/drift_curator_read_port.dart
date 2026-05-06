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
    final categories = await _db.select(_db.contentCategories).get();
    final categoryIconById = {
      for (final c in categories) c.id: c.materialIconName?.trim(),
    };
    return [
      for (final a in articles)
        TickerNewsCandidate(
          feedId: a.feedId,
          feedName: _tickerLabelForFeed(feedById[a.feedId]),
          title: a.title,
          summary: a.summary,
          categoryIconName: categoryIconById[feedById[a.feedId]?.category],
          publishedAtMs: a.publishedAt.millisecondsSinceEpoch,
        ),
    ];
  }

  @override
  Future<List<TickerDefinitionForCuration>> loadTickerDefinitionsForCuration() async {
    final rows = await (_db.select(
      _db.tickerDefinitions,
    )..orderBy([
      (t) => OrderingTerm.asc(t.sortOrder),
      (t) => OrderingTerm.asc(t.id),
    ])).get();
    return [
      for (final r in rows)
        TickerDefinitionForCuration(
          id: r.id,
          tickerType: r.tickerType,
          enabled: r.enabled,
          frequencyWeight: r.frequencyWeight,
          sortOrder: r.sortOrder,
          configKey: r.configKey,
        ),
    ];
  }

  @override
  Future<CurrentWeatherTickerData?> loadCurrentWeatherForTicker() async {
    final locations = await (_db.select(
      _db.weatherLocations,
    )..where((t) => t.enabled.equals(true))).get();
    if (locations.isEmpty) {
      return null;
    }
    final locationById = {for (final location in locations) location.id: location};
    final weatherRows = await (_db.select(
      _db.weatherCurrentData,
    )..orderBy([(t) => OrderingTerm.desc(t.observedAtMs)])).get();
    for (final weather in weatherRows) {
      final location = locationById[weather.locationId];
      if (location == null) {
        continue;
      }
      return CurrentWeatherTickerData(
        locationName: location.name,
        temperatureC: weather.currentTemp,
        description: weather.currentDescription,
      );
    }
    return null;
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
