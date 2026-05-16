import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:waddle_display/alerts/alert_severity_icons_kv.dart';
import 'package:waddle_display/config/google_kv.dart';
import 'package:waddle_data_providers/media_pexels/pexels_provider_extra_config.dart';
import 'package:waddle_shared/persistence/content_category_defaults.dart';
import 'package:waddle_shared/persistence/display_overlay_repository.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/initial_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('ensureInitialSeed is idempotent on second run', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    final providers1 = await db.select(db.integrations).get();
    await ensureInitialSeed(db);
    final providers2 = await db.select(db.integrations).get();
    expect(providers2.length, providers1.length);
    await db.close();
  });

  test('ensureInitialSeed seeds ticker_tapes defaults', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    final rows = await (db.select(db.tickerTapes)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    expect(rows.length, 6);
    expect(rows.map((r) => r.tickerType).toList(), [
      'time',
      'weather',
      'news',
      'quote',
      'stocks',
      'custom',
    ]);
    final custom =
        rows.singleWhere((r) => r.id == 'ticker_custom');
    expect(custom.enabled, isFalse);
    for (final r in rows) {
      expect(r.configJsonSchema, isNotNull);
      expect(r.exampleConfigJson, isNotNull);
      expect(jsonDecode(r.configJsonSchema!), isA<Map<String, dynamic>>());
      expect(jsonDecode(r.exampleConfigJson!), isA<Object>());
    }
    await db.close();
  });

  test('ensureInitialSeed inserts news screens with data_key news', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final left = await (db.select(db.screens)
          ..where((t) => t.id.equals('news')))
        .getSingleOrNull();
    final right = await (db.select(db.screens)
          ..where((t) => t.id.equals('news_right')))
        .getSingleOrNull();
    final columns = await (db.select(db.screens)
          ..where((t) => t.id.equals('news_columns')))
        .getSingleOrNull();
    final stack = await (db.select(db.screens)
          ..where((t) => t.id.equals('news_stack')))
        .getSingleOrNull();
    expect(left, isNotNull);
    expect(right, isNotNull);
    expect(columns, isNotNull);
    expect(stack, isNotNull);
    expect(left!.dataKey, 'news');
    expect(right!.dataKey, 'news');
    expect(columns!.dataKey, 'news');
    expect(stack!.dataKey, 'news');
    expect(left.configJson.contains('"imageOnRight":true'), isFalse);
    expect(right.configJson.contains('"imageOnRight":true'), isTrue);
    expect(columns.screenType, 'rss_article_columns');
    expect(columns.configJson.contains('"columnCount":3'), isTrue);
    expect(columns.configJson.contains('"summaryCapacityCharsPerColumn":220'), isTrue);
    expect(left.configJson.contains('"summaryCapacityChars":1200'), isTrue);
    expect(stack.screenType, 'rss_article_stack');
    await db.close();
  });

  test('ensureInitialSeed seeds curator program keys in config_key_values', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final rows = await db.select(db.configKeyValues).get();
    final byKey = {for (final r in rows) r.key: r.value};
    expect(byKey[kCuratorProgramDurationSecondsKvKey], '180');
    expect(byKey[kCuratorHistoryDepthKvKey], '5');
    expect(byKey[kRequireNewsPhotoForScreensKvKey], 'true');
    expect(byKey[kDisplayTimezoneKvKey], kDefaultDisplayTimezoneIana);
    expect(byKey.containsKey('curator.news.require_photo_for_curation'), isFalse);
    expect(byKey[kAlertSeverityIconsKvKey], kDefaultAlertSeverityIconsJson);
    await db.close();
  });

  test('ensureInitialSeed seeds content_categories with material icons', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final rows = await db.select(db.contentCategories).get();
    expect(rows.length, kContentCategoryDefaults.length);
    final tech = await (db.select(db.contentCategories)
          ..where((t) => t.id.equals('technology')))
        .getSingle();
    expect(tech.materialIconName, 'memory');
    expect(tech.iconBlobKey, isNull);
    await db.close();
  });

  test('ensureInitialSeed inserts weather provider and weather screen', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final provider = await (db.select(db.integrations)
          ..where((t) => t.id.equals('weather_openweathermap')))
        .getSingleOrNull();
    expect(provider, isNotNull);
    expect(provider!.providerType, 'weather_openweathermap');

    final nws = await (db.select(db.integrations)
          ..where((t) => t.id.equals('weather_nws_alerts')))
        .getSingleOrNull();
    expect(nws, isNotNull);
    expect(nws!.providerType, 'weather_nws_alerts');
    expect(nws.enabled, isTrue);
    expect(nws.baseUrl, 'https://api.weather.gov');

    final screen = await (db.select(db.screens)
          ..where((t) => t.id.equals('weather')))
        .getSingleOrNull();
    expect(screen, isNotNull);
    expect(screen!.screenType, 'weather');

    final locations = await (db.select(db.weatherLocations)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    expect(locations.map((e) => e.id), containsAll(<String>[
      'salt_lake_city_ut',
      'atlanta_ga',
    ]));
    await db.close();
  });

  test('ensureInitialSeed inserts media_onedrive provider disabled', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final row = await (db.select(db.integrations)
          ..where((t) => t.id.equals('media_onedrive')))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.enabled, isFalse);
    expect(row.providerType, 'media_onedrive');
    expect(row.configJson, contains('globalPerPollLimit'));
    await db.close();
  });

  test('ensureInitialSeed inserts trivia_opentdb provider disabled', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final row = await (db.select(db.integrations)
          ..where((t) => t.id.equals('trivia_opentdb')))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.enabled, isFalse);
    expect(row.providerType, 'trivia_opentdb');
    expect(row.baseUrl, 'https://opentdb.com/api.php');
    expect(row.configJson, contains('"amount"'));
    await db.close();
  });

  test('ensureInitialSeed inserts media_flickr provider disabled', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final row = await (db.select(db.integrations)
          ..where((t) => t.id.equals('media_flickr')))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.enabled, isFalse);
    expect(row.providerType, 'media_flickr');
    expect(row.configJson, contains('"groupIds"'));
    await db.close();
  });

  test('ensureInitialSeed inserts media_bing_iotd provider enabled', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final row = await (db.select(db.integrations)
          ..where((t) => t.id.equals('media_bing_iotd')))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.enabled, isTrue);
    expect(row.providerType, 'media_bing_iotd');
    expect(row.baseUrl, 'https://www.bing.com');
    expect(row.configJson, contains('"resolution":"UHD"'));
    expect(row.configJson, contains('"category":"bing"'));
    await db.close();
  });

  test('ensureInitialSeed seeds pexels source queries and categories', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final provider = await (db.select(db.integrations)
          ..where((t) => t.id.equals('media_pexels')))
        .getSingleOrNull();
    expect(provider, isNotNull);
    final extra = PexelsProviderExtraConfig.parse(provider!.configJson);
    expect(
      extra.sources.map((e) => e.query).toList(),
      [
        'Nature',
        'Flowers',
        'Landscape',
        'Beach',
        'Mountains',
        'Motivational',
        'Aquarium',
      ],
    );
    expect(
      extra.sources.map((e) => e.category).toList(),
      [
        'nature',
        'flowers',
        'landscape',
        'beach',
        'mountains',
        'motivational',
        'aquarium',
      ],
    );
    await db.close();
  });

  test('ensureInitialSeed inserts calendar_google provider (no google client id KV)', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);

    final provider = await (db.select(db.integrations)
          ..where((t) => t.id.equals('calendar_google')))
        .getSingleOrNull();
    expect(provider, isNotNull);
    expect(provider!.providerType, 'calendar_google');
    expect(provider.enabled, isFalse);

    final clientId = await (db.select(db.configKeyValues)
          ..where((t) => t.key.equals(kGoogleClientIdKvKey)))
        .getSingleOrNull();
    expect(clientId, isNull);

    await db.close();
  });

  test('ensureInitialSeed inserts stocks provider, default symbols, screen', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureInitialSeed(db);

    final provider = await (db.select(db.integrations)
          ..where((t) => t.id.equals('stock_finnhub')))
        .getSingleOrNull();
    expect(provider, isNotNull);
    expect(provider!.providerType, 'stock_finnhub');
    expect(provider.enabled, isTrue);
    expect(provider.baseUrl, 'https://finnhub.io');

    final screen = await (db.select(db.screens)
          ..where((t) => t.id.equals('stock_quotes')))
        .getSingleOrNull();
    expect(screen, isNotNull);
    expect(screen!.enabled, isFalse);
    expect(screen.screenType, 'stock_quotes');
    expect(screen.dataKey, 'stocks');

    final symbols = await (db.select(db.stockSymbols)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    expect(
      symbols.map((s) => s.symbol).toList(),
      [
        'AAPL',
        'AMZN',
        'CSCO',
        'DIS',
        'GOOG',
        'IBM',
        'INTC',
        'IWM',
        'META',
        'MSFT',
        'NFLX',
        'NVDA',
        'ORCL',
        'QQQ',
        'SPY',
        'TSLA',
        'VOO',
      ],
    );
    final enabled = symbols.where((s) => s.enabled).map((s) => s.symbol).toSet();
    expect(enabled, {'AAPL', 'GOOG', 'MSFT', 'NVDA', 'SPY', 'VOO'});
    await db.close();
  });

  test('ensureInitialSeed inserts disabled May 13 birthday confetti example', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    final rows = await fetchDisplayOverlaySchedules(db);
    final birthday = rows
        .where((r) => r.id == kDefaultBirthdayOverlayExampleId)
        .toList();
    expect(birthday, isNotEmpty);
    final r = birthday.single;
    expect(r.enabled, isFalse);
    expect(r.overlayType, kOverlayTypeBirthdayConfetti);
    expect(r.repeatAnnually, isTrue);
    expect(r.startMonth, 5);
    expect(r.startDay, 13);
    expect(r.nthWeekOfMonth, isNull);
    expect(r.nthWeekday, isNull);
    await db.close();
  });

  test('ensureInitialSeed inserts disabled May 13 bouncing message overlay', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);
    final rows = await fetchDisplayOverlaySchedules(db);
    final bounce = rows
        .where((r) => r.id == kDefaultBouncingMessageOverlayId)
        .toList();
    expect(bounce, isNotEmpty);
    final r = bounce.single;
    expect(r.enabled, isFalse);
    expect(r.overlayType, kOverlayTypeBouncingMessage);
    expect(r.repeatAnnually, isTrue);
    expect(r.startMonth, 5);
    expect(r.startDay, 13);
    expect(
      (jsonDecode(r.configJson) as Map<String, dynamic>)['messages'],
      [kDefaultBouncingMessageOverlayPhrase],
    );
    await db.close();
  });
}
