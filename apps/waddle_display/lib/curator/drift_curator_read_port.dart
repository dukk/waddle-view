import 'package:drift/drift.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';

import 'package:waddle_shared/persistence/database.dart';
import 'curator_read_port.dart';
import 'ticker_news_candidate.dart';

int _severityRank(String? severity) {
  switch ((severity ?? '').toLowerCase().trim()) {
    case 'extreme':
      return 0;
    case 'severe':
      return 1;
    case 'moderate':
      return 2;
    case 'minor':
      return 3;
    default:
      return 4;
  }
}

String _capTickerAlertBody(String body, int maxLen) {
  final t = body.trim();
  if (t.length <= maxLen) {
    return t;
  }
  if (maxLen <= 1) {
    return '';
  }
  return '${t.substring(0, maxLen - 1)}\u2026';
}

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
    final articles = await (_db.select(_db.rssArticles)
          ..where((t) => t.suppressed.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)]))
        .get();
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
  Future<List<StockTickerRowForMarquee>> loadStockRowsForTicker() async {
    final symbols = await (_db.select(
      _db.stockSymbols,
    )..where((t) => t.enabled.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.symbol)])).get();
    if (symbols.isEmpty) {
      return const [];
    }
    final quotes = await _db.select(_db.stockQuotes).get();
    final quoteBySymbolId = {for (final q in quotes) q.symbolId: q};
    return [
      for (final sym in symbols)
        (
          symbolId: sym.id,
          symbol: sym.symbol,
          displayName: sym.displayName,
          currentPrice: quoteBySymbolId[sym.id]?.currentPrice,
          percentChange: quoteBySymbolId[sym.id]?.percentChange,
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

  @override
  Future<List<WeatherGovAlertTickerItem>> loadWeatherGovAlertsForTicker() async {
    final locations = await (_db.select(
      _db.weatherLocations,
    )..where((t) => t.enabled.equals(true))).get();
    if (locations.isEmpty) {
      return const [];
    }
    final locationById = {for (final l in locations) l.id: l};
    final rows = await _db.select(_db.weatherGovActiveAlerts).get();
    final filtered = [
      for (final a in rows)
        if (locationById.containsKey(a.locationId)) a,
    ]..sort((a, b) {
      final s = _severityRank(a.severity).compareTo(_severityRank(b.severity));
      if (s != 0) {
        return s;
      }
      final loc = a.locationId.compareTo(b.locationId);
      if (loc != 0) {
        return loc;
      }
      return a.event.compareTo(b.event);
    });
    final seenNwsIds = <String>{};
    final out = <WeatherGovAlertTickerItem>[];
    for (final a in filtered) {
      if (!seenNwsIds.add(a.nwsAlertId)) {
        continue;
      }
      final loc = locationById[a.locationId]!;
      final headline = (a.headline ?? '').trim();
      final event = a.event.trim();
      final parts = <String>[loc.name, if (event.isNotEmpty) event];
      if (headline.isNotEmpty) {
        parts.add(headline);
      }
      final body = _capTickerAlertBody(parts.join(' — '), 160);
      if (body.isEmpty) {
        continue;
      }
      out.add(
        WeatherGovAlertTickerItem(
          body: body,
          sourceId: 'nws.alert.${a.nwsAlertId}',
        ),
      );
    }
    return out;
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

  @override
  Future<RejectFilterContext> loadRejectFilterContext() =>
      RejectFilterContext.loadFromDb(_db);
}
