import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/seed/tables/ticker_tape_types_seed.dart';

Future<void> ensureTickerTapesSeed(AppDatabase db) async {
  await ensureTickerTapeTypes(db);
  Future<void> upsert({
    required String id,
    required String label,
    String description = '',
    required String tickerType,
    int frequencyWeight = 100,
    int sortOrder = 0,
    String? configJson,
  }) async {
    await db.into(db.tickerTapes).insertOnConflictUpdate(
          TickerTapesCompanion.insert(
            id: id,
            label: label,
            description: Value(description),
            tickerType: tickerType,
            frequencyWeight: Value(frequencyWeight),
            sortOrder: Value(sortOrder),
            configJson: configJson == null
                ? const Value.absent()
                : Value(configJson),
          ),
        );
  }

  Future<void> ensureTapeStaticTextIfUnset(String id, String text) async {
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
        configJson: Value(jsonEncode({'text': text})),
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
    description: 'Live weather from collect',
    tickerType: 'weather',
    sortOrder: 10,
  );
  await upsert(
    id: 'ticker_news',
    label: 'News',
    description: 'RSS headlines from stored articles',
    tickerType: 'news',
    sortOrder: 20,
  );
  await upsert(
    id: 'ticker_stocks',
    label: 'Stock quotes',
    description: 'Enabled interests_stock_symbols with latest stock_quotes',
    tickerType: 'stocks',
    sortOrder: 35,
  );
  await upsert(
    id: 'ticker_custom',
    label: 'Static text',
    description: 'Fixed line from config_json text',
    tickerType: 'static_text',
    sortOrder: 40,
  );

  await ensureTapeStaticTextIfUnset('ticker_custom', 'Thanks for visiting');
}
