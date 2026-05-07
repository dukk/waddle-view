import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/curator/drift_curator_read_port.dart';
import 'package:waddle_display/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test('loadKeyValuesForCuration maps config_key_values rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.configKeyValues).insert(
          ConfigKeyValuesCompanion.insert(
            key: 'ticker.marquee.news',
            value: 'Hello',
          ),
        );
    final port = DriftCuratorReadPort(db);
    final kv = await port.loadKeyValuesForCuration();
    expect(kv['ticker.marquee.news'], 'Hello');
    await db.close();
  });

  test('loadNewsCandidatesForTicker uses feed title for feedName', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
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
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
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
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
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

  test('loadTickerDefinitionsForCuration returns rows ordered by sort_order', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.tickerDefinitions).insert(
          TickerDefinitionsCompanion.insert(
            id: 'b',
            name: 'B',
            tickerType: 'quote',
            sortOrder: const Value(10),
          ),
        );
    await db.into(db.tickerDefinitions).insert(
          TickerDefinitionsCompanion.insert(
            id: 'a',
            name: 'A',
            tickerType: 'time',
            sortOrder: const Value(0),
          ),
        );
    final port = DriftCuratorReadPort(db);
    final list = await port.loadTickerDefinitionsForCuration();
    expect(list.map((e) => e.id).toList(), ['a', 'b']);
    expect(list.first.tickerType, 'time');
    await db.close();
  });

  test('loadStockRowsForTicker returns empty list when no enabled symbols', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.stockSymbols).insert(
          StockSymbolsCompanion.insert(
            id: 'gone',
            symbol: 'GONE',
            enabled: const Value(false),
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
    await db.into(db.stockSymbols).insert(
          StockSymbolsCompanion.insert(
            id: 'msft',
            symbol: 'MSFT',
            displayName: const Value('Microsoft'),
          ),
        );
    await db.into(db.stockSymbols).insert(
          StockSymbolsCompanion.insert(
            id: 'aapl',
            symbol: 'AAPL',
          ),
        );
    await db.into(db.stockSymbols).insert(
          StockSymbolsCompanion.insert(
            id: 'gone',
            symbol: 'GONE',
            enabled: const Value(false),
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
    await db.into(db.weatherLocations).insert(
          WeatherLocationsCompanion.insert(
            id: 'atlanta',
            name: 'Atlanta, GA',
            latitude: 33.749,
            longitude: -84.388,
          ),
        );
    await db.into(db.weatherCurrentData).insert(
          WeatherCurrentDataCompanion.insert(
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
}
