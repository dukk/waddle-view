import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/database.dart';

Future<void> ensureTickerTapesSeed(AppDatabase db) async {
  Future<void> upsert({
    required String id,
    required String label,
    String description = '',
    required String tickerType,
    int frequencyWeight = 100,
    int sortOrder = 0,
    String? configKey,
  }) async {
    final doc = tickerSlotConfigJsonDocForType(tickerType);
    await db.into(db.tickerTapes).insertOnConflictUpdate(
          TickerTapesCompanion.insert(
            id: id,
            label: label,
            description: Value(description),
            tickerType: tickerType,
            frequencyWeight: Value(frequencyWeight),
            sortOrder: Value(sortOrder),
            configKey: configKey == null
                ? const Value.absent()
                : Value(configKey),
            configJson: const Value.absent(),
            configJsonSchema: Value(doc.schema),
            exampleConfigJson: Value(doc.example),
          ),
        );
  }

  Future<void> ensureTapeFallbackIfUnset(String id, String fallback) async {
    final r = await (db.select(db.tickerTapes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (r == null) {
      return;
    }
    final raw = r.configJson.trim();
    if (raw.isNotEmpty && raw != '{}') {
      return;
    }
    await (db.update(db.tickerTapes)..where((t) => t.id.equals(id))).write(
      TickerTapesCompanion(
        configJson: Value(jsonEncode({'fallbackText': fallback})),
      ),
    );
  }

  await upsert(
    id: 'ticker_time',
    label: 'Time',
    description: 'Local clock string',
    tickerType: 'time',
    sortOrder: 0,
  );
  await upsert(
    id: 'ticker_weather',
    label: 'Weather',
    description: 'Live weather; optional fallbackText in config_json',
    tickerType: 'weather',
    sortOrder: 10,
  );
  await upsert(
    id: 'ticker_news',
    label: 'News',
    description: 'RSS headlines; optional fallbackText in config_json',
    tickerType: 'news',
    sortOrder: 20,
  );
  await upsert(
    id: 'ticker_quote',
    label: 'Quote',
    description: 'Static line from config_json fallbackText',
    tickerType: 'quote',
    sortOrder: 30,
  );
  await upsert(
    id: 'ticker_stocks',
    label: 'Stocks',
    description: 'Enabled interests_stock_symbols with latest stock_quotes',
    tickerType: 'stocks',
    sortOrder: 35,
  );
  await upsert(
    id: 'ticker_custom',
    label: 'Custom marquee',
    description: 'Extra ticker.marquee.* keys in config_key_values (not in bootstrap curator)',
    tickerType: 'custom',
    sortOrder: 40,
  );

  await ensureTapeFallbackIfUnset('ticker_weather', '— °F · demo');
  await ensureTapeFallbackIfUnset('ticker_news', 'Welcome to Waddle View');
  await ensureTapeFallbackIfUnset(
    'ticker_quote',
    'Market data updates after each collect',
  );
}
