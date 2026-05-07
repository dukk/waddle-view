import 'package:drift/drift.dart';

import '../../persistence/database.dart';

Future<void> ensureTickerDefinitionsSeed(AppDatabase db) async {
  Future<void> upsert({
    required String id,
    required String name,
    String description = '',
    bool enabled = true,
    required String tickerType,
    int frequencyWeight = 100,
    int sortOrder = 0,
    String? configKey,
  }) async {
    await db.into(db.tickerDefinitions).insertOnConflictUpdate(
          TickerDefinitionsCompanion.insert(
            id: id,
            name: name,
            description: Value(description),
            enabled: Value(enabled),
            tickerType: tickerType,
            frequencyWeight: Value(frequencyWeight),
            sortOrder: Value(sortOrder),
            configKey: configKey == null
                ? const Value.absent()
                : Value(configKey),
          ),
        );
  }

  await upsert(
    id: 'ticker_time',
    name: 'Time',
    description: 'Local clock string',
    tickerType: 'time',
    sortOrder: 0,
  );
  await upsert(
    id: 'ticker_weather',
    name: 'Weather',
    description: 'Live weather or ticker.marquee.weather',
    tickerType: 'weather',
    sortOrder: 10,
  );
  await upsert(
    id: 'ticker_news',
    name: 'News',
    description: 'RSS headlines or ticker.marquee.news',
    tickerType: 'news',
    sortOrder: 20,
  );
  await upsert(
    id: 'ticker_quote',
    name: 'Quote',
    description: 'ticker.marquee.quote',
    tickerType: 'quote',
    sortOrder: 30,
  );
  await upsert(
    id: 'ticker_stocks',
    name: 'Stocks',
    description: 'Enabled stock_symbols with latest stock_quotes',
    tickerType: 'stocks',
    sortOrder: 35,
  );
  await upsert(
    id: 'ticker_custom',
    name: 'Custom marquee',
    description: 'Extra ticker.marquee.* keys (disabled by default)',
    enabled: false,
    tickerType: 'custom',
    sortOrder: 40,
  );
}
