import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/curator/drift_curator_read_port.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test('loadKeyValuesForCuration maps config_key_values rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(
            key: 'header.subtitle',
            value: 'Hello',
          ),
        );
    final port = DriftCuratorReadPort(db);
    final kv = await port.loadKeyValuesForCuration();
    expect(kv['header.subtitle'], 'Hello');
    await db.close();
  });

  test('loadNewsCandidatesForTicker uses feed title for feedName', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.interestsRssFeeds).insert(
          InterestsRssFeedsCompanion.insert(
            id: 'f1',
            url: 'http://x',
            title: const Value('US Top Stories'),
            category: const Value('usa'),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'a1',
            feedId: 'f1',
            guid: 'g1',
            title: 'Headline',
            link: 'http://l',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final port = DriftCuratorReadPort(db);
    final list = await port.loadNewsCandidatesForTicker();
    expect(list.single.feedName, 'US Top Stories');
    await db.close();
  });

  test('loadNewsCandidatesForTicker falls back to category when title empty', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.interestsRssFeeds).insert(
          InterestsRssFeedsCompanion.insert(
            id: 'f1',
            url: 'http://x',
            category: const Value('world'),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'a1',
            feedId: 'f1',
            guid: 'g1',
            title: 'Headline',
            link: 'http://l',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final port = DriftCuratorReadPort(db);
    final list = await port.loadNewsCandidatesForTicker();
    expect(list.single.feedName, 'world');
    await db.close();
  });

  test('loadNewsCandidatesForTicker includes category icon name when available', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.contentCategories).insert(
          ContentCategoriesCompanion.insert(
            id: 'world',
            label: 'World',
            materialIconName: const Value('public'),
          ),
        );
    await db.into(db.interestsRssFeeds).insert(
          InterestsRssFeedsCompanion.insert(
            id: 'f1',
            url: 'http://x',
            category: const Value('world'),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'a1',
            feedId: 'f1',
            guid: 'g1',
            title: 'Headline',
            link: 'http://l',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final port = DriftCuratorReadPort(db);
    final list = await port.loadNewsCandidatesForTicker();
    expect(list.single.categoryIconName, 'public');
    await db.close();
  });

  test('loadNewsCandidatesForTicker omits suppressed articles', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.interestsRssFeeds).insert(
          InterestsRssFeedsCompanion.insert(
            id: 'f1',
            url: 'http://x',
            title: const Value('Feed'),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'hid',
            feedId: 'f1',
            guid: 'g0',
            title: 'Bad',
            link: 'http://a',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(3),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(3),
            suppressed: const Value(true),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'vis',
            feedId: 'f1',
            guid: 'g1',
            title: 'Ok',
            link: 'http://b',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(2),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(2),
          ),
        );
    final port = DriftCuratorReadPort(db);
    final list = await port.loadNewsCandidatesForTicker();
    expect(list, hasLength(1));
    expect(list.single.title, 'Ok');
    await db.close();
  });

  test('loadTickerTapesForCuration returns rows ordered by sort_order', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.tickerTapes).insert(
          TickerTapesCompanion.insert(
            id: 'b',
            name: 'B',
            tickerType: 'quote',
            sortOrder: const Value(10),
          ),
        );
    await db.into(db.tickerTapes).insert(
          TickerTapesCompanion.insert(
            id: 'a',
            name: 'A',
            tickerType: 'time',
            sortOrder: const Value(0),
          ),
        );
    final port = DriftCuratorReadPort(db);
    final list = await port.loadTickerTapesForCuration();
    expect(list.map((e) => e.id).toList(), ['a', 'b']);
    expect(list.first.tickerType, 'time');
    expect(list.first.configJson, '{}');
    await db.close();
  });

  test('loadStockRowsForTicker returns empty list when no enabled symbols', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'gone',
            symbol: 'GONE',
            includeWeather: const Value(false),
          ),
        );
    final port = DriftCuratorReadPort(db);
    final rows = await port.loadStockRowsForTicker();
    expect(rows, isEmpty);
    await db.close();
  });

  test('loadStockRowsForTicker returns enabled symbols ordered by symbol with quotes', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'msft',
            symbol: 'MSFT',
            displayName: const Value('Microsoft'),
          ),
        );
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'aapl',
            symbol: 'AAPL',
          ),
        );
    await db.into(db.interestsStockSymbols).insert(
          InterestsStockSymbolsCompanion.insert(
            id: 'gone',
            symbol: 'GONE',
            includeWeather: const Value(false),
          ),
        );
    await db.into(db.stockQuotes).insert(
          StockQuotesCompanion.insert(
            symbolId: 'aapl',
            currentPrice: const Value(100),
            percentChange: const Value(-0.5),
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final port = DriftCuratorReadPort(db);
    final rows = await port.loadStockRowsForTicker();
    expect(rows.map((r) => r.symbol).toList(), ['AAPL', 'MSFT']);
    expect(rows.first.symbolId, 'aapl');
    expect(rows.first.currentPrice, 100);
    expect(rows.first.percentChange, -0.5);
    expect(rows[1].currentPrice, equals(null));
    await db.close();
  });

  test('loadCurrentWeatherForTicker returns enabled location weather', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'atlanta',
            name: 'Atlanta, GA',
            latitude: 33.749,
            longitude: -84.388,
            includeWeather: const Value(true),
          ),
        );
    await db.into(db.weatherCurrent).insert(
          WeatherCurrentCompanion.insert(
            locationId: 'atlanta',
            observedAtMs: DateTime.fromMillisecondsSinceEpoch(2),
            currentTemp: const Value(24.4),
            currentDescription: const Value('partly cloudy'),
          ),
        );
    final port = DriftCuratorReadPort(db);
    final weather = await port.loadCurrentWeatherForTicker();
    expect(weather, isNot(equals(null)));
    expect(weather!.locationName, 'Atlanta, GA');
    expect(weather.temperatureC, 24.4);
    expect(weather.description, 'partly cloudy');
    await db.close();
  });

  test('loadWeatherGovAlertsForTicker maps enabled locations and dedupes NWS ids', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'atlanta',
            name: 'Atlanta, GA',
            latitude: 33.749,
            longitude: -84.388,
            includeWeather: const Value(true),
          ),
        );
    await db.into(db.interestsLocations).insert(
          InterestsLocationsCompanion.insert(
            id: 'denver',
            name: 'Denver, CO',
            latitude: 39.7392,
            longitude: -104.9903,
            includeWeather: const Value(true),
          ),
        );
    await db.into(db.weatherAlerts).insert(
          WeatherAlertsCompanion.insert(
            locationId: 'atlanta',
            nwsAlertId: 'urn:dup:1',
            event: 'Heat Advisory',
            headline: const Value('Hot'),
            severity: const Value('Moderate'),
          ),
        );
    await db.into(db.weatherAlerts).insert(
          WeatherAlertsCompanion.insert(
            locationId: 'denver',
            nwsAlertId: 'urn:dup:1',
            event: 'Duplicate id',
            headline: const Value('Later'),
            severity: const Value('Moderate'),
          ),
        );
    final port = DriftCuratorReadPort(db);
    final list = await port.loadWeatherGovAlertsForTicker();
    expect(list, hasLength(1));
    expect(list.single.sourceId, 'nws.alert.urn:dup:1');
    expect(list.single.body, contains('Atlanta'));
    expect(list.single.body, contains('Heat Advisory'));
    await db.close();
  });
}
