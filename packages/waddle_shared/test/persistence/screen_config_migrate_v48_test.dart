import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/screen_config_migrate.dart';

void main() {
  test('migrateScreenConfigJsonV48 rewrites legacy news and weather keys', () async {
    final db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    await db.into(db.contentCategories).insert(
          ContentCategoriesCompanion.insert(
            id: 'family',
            label: 'Family',
            materialIconName: const Value('family_restroom'),
          ),
        );

    await db.into(db.screens).insert(
          ScreensCompanion.insert(
            id: 'news_main',
            screenType: 'news',
            label: 'News',
            configJson: Value(jsonEncode({
              'feedId': 'feed-1',
              'categoryId': 'family',
              'imageOnRight': true,
            })),
          ),
        );
    await db.into(db.screens).insert(
          ScreensCompanion.insert(
            id: 'weather_main',
            screenType: 'weather',
            label: 'Weather',
            configJson: Value(jsonEncode({'locationId': 'sea'})),
          ),
        );
    await db.into(db.screens).insert(
          ScreensCompanion.insert(
            id: 'stocks',
            screenType: 'stock_quotes',
            label: 'Stocks',
            configJson: Value(jsonEncode({'symbolIds': ['aapl', 'msft']})),
          ),
        );

    await migrateScreenConfigJsonV48(db);

    final newsRow =
        await (db.select(db.screens)..where((t) => t.id.equals('news_main'))).getSingle();
    final news = jsonDecode(newsRow.configJson) as Map<String, dynamic>;
    expect(news['feedId'], isNull);
    expect(news['categoryName'], 'Family');
    expect(news['qrMode'], 'right');

    final weatherRow =
        await (db.select(db.screens)..where((t) => t.id.equals('weather_main'))).getSingle();
    final weather = jsonDecode(weatherRow.configJson) as Map<String, dynamic>;
    expect(weather['locationId'], isNull);
    expect(weather['locationName'], 'sea');

    final stocksRow =
        await (db.select(db.screens)..where((t) => t.id.equals('stocks'))).getSingle();
    final stocks = jsonDecode(stocksRow.configJson) as Map<String, dynamic>;
    expect(stocks['symbolIds'], isNull);
    expect(stocks['symbols'], ['AAPL', 'MSFT']);

    await db.close();
  });
}
