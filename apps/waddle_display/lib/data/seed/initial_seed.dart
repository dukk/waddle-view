import 'package:drift/drift.dart';

import '../../alerts/alert_severity_icons_kv.dart';
import '../../config/google_kv.dart';
import '../../config/microsoft_graph_kv.dart';
import '../../curator/photo_collage_curation.dart';
import '../../persistence/config_json_documentation.dart';
import '../../persistence/database.dart';
import '../../persistence/tables.dart';
import '../../theme/display_text_scale_kv.dart';
import '../../theme/display_theme_kv.dart';
import 'tables/content_categories_seed.dart';
import 'tables/joke_categories_seed.dart';
import 'tables/rss_feed_sources_seed.dart';
import 'tables/trivia_categories_seed.dart';

/// Idempotent demo rows for stub provider + ticker.
Future<void> ensureInitialSeed(AppDatabase db) async {
  final existing = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals('stub'))).getSingleOrNull();
  if (existing == null) {
    final stubDoc = providerConfigJsonDocForType('stub');
    await db
        .into(db.providerSettings)
        .insert(
          ProviderSettingsCompanion.insert(
            id: 'stub',
            providerType: 'stub',
            enabled: const Value(true),
            pollSeconds: const Value(60),
            configJsonSchema: Value(stubDoc.schema),
            exampleConfigJson: Value(stubDoc.example),
          ),
        );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: 'ticker.marquee.news',
            value: 'Welcome to Waddle View',
          ),
        );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: 'ticker.marquee.weather',
            value: '— °F · demo',
          ),
        );
    await db
        .into(db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: 'ticker.marquee.quote',
            value: 'Market data updates after each collect',
          ),
        );
  }
  await _ensureProviderRow(
    db,
    id: 'rss',
    providerType: 'rss',
    pollSeconds: 3600,
  );
  await _ensureJokesProviderRow(db);
  await _ensureTriviaProviderRow(db);
  await _ensureOpenTdbTriviaProviderRow(db);
  await _ensureWeatherProviderRow(db);
  await _ensureNwsWeatherAlertsProviderRow(db);
  await _ensurePexelsProviderRow(db);
  await _ensureStocksProviderRow(db);
  await _ensureDefaultStockSymbols(db);
  await _ensureMicrosoftGraphClientIdKv(db);
  await _ensureGoogleClientIdKv(db);
  await _ensureGoogleCalendarProviderRow(db);
  await _ensureOutlookCalendarProviderRow(db);
  await _ensureOneDriveMediaProviderRow(db);
  await _ensureFlickrMediaProviderRow(db);
  await _ensureBingImageOfDayProviderRow(db);
  await _ensureDefaultWeatherLocations(db);
  await ensureDefaultContentCategories(db);
  await ensureDefaultJokeCategories(db);
  await ensureDefaultTriviaCategories(db);
  await ensureDefaultRssNewsFeeds(db);
  await _ensureCuratorSettings(db);
  await _ensureTickerDefinitions(db);
  await _ensureDisplayThemeKv(db);
  await _ensureDisplayTextScaleKv(db);
  await _ensureAlertSeverityIconsKv(db);
  await _ensureWelcomeScreen(db);
  await _ensureJokeScreen(db);
  await _ensureTriviaScreen(db);
  await _ensureGuestWifiScreen(db);
  await _ensureNewsScreen(db);
  await _ensureNewsRightImageScreen(db);
  await _ensureNewsColumnsScreen(db);
  await _ensureNewsStackScreen(db);
  await _ensureClockDataKeyLimit(db);
  await _ensureClockDigitalScreen(db);
  await _ensureClockAnalogScreen(db);
  await _ensureCalendarScreen(db);
  await _ensureLocalApiScreen(db);
  await _ensureAdminSetupScreen(db);
  await _ensureWeatherScreen(db);
  await _ensurePexelsPhotoScreen(db);
  await _ensurePexelsVideoScreen(db);
  await _ensurePhotoCollageScreens(db);
  await _ensureStockQuotesScreen(db);
}

Future<void> _ensureDisplayThemeKv(AppDatabase db) async {
  final row = await (db.select(
    db.configKeyValues,
  )..where((t) => t.key.equals(kDisplayThemeIdKvKey))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.configKeyValues)
      .insert(
        ConfigKeyValuesCompanion.insert(
          key: kDisplayThemeIdKvKey,
          value: kDefaultDisplayThemeId,
        ),
      );
}

Future<void> _ensureDisplayTextScaleKv(AppDatabase db) async {
  Future<void> ensureKey(String key, String value) async {
    final row = await (db.select(
      db.configKeyValues,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row != null) {
      return;
    }
    await db
        .into(db.configKeyValues)
        .insert(ConfigKeyValuesCompanion.insert(key: key, value: value));
  }

  await ensureKey(kDisplayTextScaleScreenKvKey, kDisplayTextScaleNormal);
  await ensureKey(kDisplayTextScaleTickerKvKey, kDisplayTextScaleNormal);
}

Future<void> _ensureAlertSeverityIconsKv(AppDatabase db) async {
  final row = await (db.select(
    db.configKeyValues,
  )..where((t) => t.key.equals(kAlertSeverityIconsKvKey))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.configKeyValues)
      .insert(
        ConfigKeyValuesCompanion.insert(
          key: kAlertSeverityIconsKvKey,
          value: kDefaultAlertSeverityIconsJson,
        ),
      );
}

Future<void> _ensureTickerDefinitions(AppDatabase db) async {
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
    await db
        .into(db.tickerDefinitions)
        .insertOnConflictUpdate(
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

Future<void> _ensureCuratorSettings(AppDatabase db) async {
  Future<void> ensureKey(String key, String value) async {
    final row = await (db.select(
      db.configKeyValues,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row != null) {
      return;
    }
    await db
        .into(db.configKeyValues)
        .insert(ConfigKeyValuesCompanion.insert(key: key, value: value));
  }

  await ensureKey(kCuratorProgramDurationSecondsKvKey, '180');
  await ensureKey(kCuratorHistoryDepthKvKey, '5');
  await ensureKey(kRequireNewsPhotoForScreensKvKey, 'true');
  await (db.delete(db.configKeyValues)
        ..where((t) => t.key.equals('curator.news.require_photo_for_curation')))
      .go();
}

Future<void> _ensureWelcomeScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('welcome'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'welcome',
          name: 'Welcome',
          description: const Value('Demo display screen'),
          screenType: 'static_text',
          configJson: const Value(
            '{"text":"Welcome to Waddle View"}',
          ),
          configJsonSchema: Value(
            screenConfigJsonDocForType('static_text').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('static_text').example,
          ),
          dwellSeconds: const Value(10),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureJokeScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('jokes'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'jokes',
          name: 'Jokes',
          description: const Value('Random joke with delayed punchline'),
          screenType: 'joke',
          configJson: const Value('{}'),
          configJsonSchema: Value(
            screenConfigJsonDocForType('joke').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('joke').example,
          ),
          dwellSeconds: const Value(20),
          dataKey: const Value('jokes'),
        ),
      );
}

Future<void> _ensureTriviaScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('trivia'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'trivia',
          name: 'Trivia',
          description: const Value(
            'Trivia with progress reveal and strike-out wrong answers (multiple-choice + true/false)',
          ),
          screenType: 'trivia',
          configJson: const Value('{}'),
          configJsonSchema: Value(
            screenConfigJsonDocForType('trivia').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('trivia').example,
          ),
          dwellSeconds: const Value(16),
          maxPlacementsPerProgram: const Value(1),
          dataKey: const Value('trivia'),
        ),
      );
}

Future<void> _ensureGuestWifiScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('guest_wifi'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'guest_wifi',
          name: 'Guest WiFi',
          description: const Value('QR and credentials for guest network'),
          screenType: 'guest_wifi',
          configJson: const Value('{}'),
          configJsonSchema: Value(
            screenConfigJsonDocForType('guest_wifi').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('guest_wifi').example,
          ),
          dwellSeconds: const Value(18),
          maxPlacementsPerProgram: const Value(1),
          dataKey: const Value('guest_wifi'),
        ),
      );
}

Future<void> _ensureNewsScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('news'))).getSingleOrNull();
  if (row != null) {
    await (db.update(
      db.screenDefinitions,
    )..where((t) => t.id.equals('news'))).write(
      ScreenDefinitionsCompanion(
        dataKey: const Value('news'),
        maxPlacementsPerProgram: const Value(null),
        minPlacementsPerProgram: const Value(1),
        screenType: const Value('rss_article'),
        configJson: const Value(
          '{"scrollDelayMs":2500,"trailingHoldMs":2000,"scrollPixelsPerSecond":48,"minReadMs":8000,"summaryCapacityChars":1200}',
        ),
        configJsonSchema: Value(
          screenConfigJsonDocForType('rss_article').schema,
        ),
        exampleConfigJson: Value(
          screenConfigJsonDocForType('rss_article').example,
        ),
      ),
    );
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'news',
          name: 'News',
          description: const Value(
            'RSS story with image and scrolling summary',
          ),
          screenType: 'rss_article',
          configJson: const Value(
            '{"scrollDelayMs":2500,"trailingHoldMs":2000,"scrollPixelsPerSecond":48,"minReadMs":8000,"summaryCapacityChars":1200}',
          ),
          configJsonSchema: Value(
            screenConfigJsonDocForType('rss_article').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('rss_article').example,
          ),
          dwellSeconds: const Value(12),
          dataKey: const Value('news'),
        ),
      );
}

Future<void> _ensureNewsRightImageScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('news_right'))).getSingleOrNull();
  if (row != null) {
    await (db.update(
      db.screenDefinitions,
    )..where((t) => t.id.equals('news_right'))).write(
      ScreenDefinitionsCompanion(
        dataKey: const Value('news'),
        screenType: const Value('rss_article'),
        configJson: const Value(
          '{"scrollDelayMs":2500,"trailingHoldMs":2000,"scrollPixelsPerSecond":48,"minReadMs":8000,"imageOnRight":true,"summaryCapacityChars":1200}',
        ),
        configJsonSchema: Value(
          screenConfigJsonDocForType('rss_article').schema,
        ),
        exampleConfigJson: Value(
          screenConfigJsonDocForType('rss_article').example,
        ),
      ),
    );
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'news_right',
          name: 'News (image right)',
          description: const Value(
            'RSS story with image on the right and scrolling summary',
          ),
          screenType: 'rss_article',
          configJson: const Value(
            '{"scrollDelayMs":2500,"trailingHoldMs":2000,"scrollPixelsPerSecond":48,"minReadMs":8000,"imageOnRight":true,"summaryCapacityChars":1200}',
          ),
          configJsonSchema: Value(
            screenConfigJsonDocForType('rss_article').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('rss_article').example,
          ),
          dwellSeconds: const Value(12),
          dataKey: const Value('news'),
        ),
      );
}

Future<void> _ensureNewsColumnsScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('news_columns'))).getSingleOrNull();
  if (row != null) {
    await (db.update(
      db.screenDefinitions,
    )..where((t) => t.id.equals('news_columns'))).write(
      ScreenDefinitionsCompanion(
        dataKey: const Value('news'),
        screenType: const Value('rss_article_columns'),
        configJson: const Value(
          '{"columnCount":3,"minReadMs":10000,"summaryCapacityCharsPerColumn":220}',
        ),
        configJsonSchema: Value(
          screenConfigJsonDocForType('rss_article_columns').schema,
        ),
        exampleConfigJson: Value(
          screenConfigJsonDocForType('rss_article_columns').example,
        ),
      ),
    );
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'news_columns',
          name: 'News (3 columns)',
          description: const Value(
            'Three RSS stories: image above title and summary in each column',
          ),
          screenType: 'rss_article_columns',
          configJson: const Value(
            '{"columnCount":3,"minReadMs":10000,"summaryCapacityCharsPerColumn":220}',
          ),
          configJsonSchema: Value(
            screenConfigJsonDocForType('rss_article_columns').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('rss_article_columns').example,
          ),
          dwellSeconds: const Value(16),
          dataKey: const Value('news'),
        ),
      );
}

Future<void> _ensureNewsStackScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('news_stack'))).getSingleOrNull();
  if (row != null) {
    await (db.update(
      db.screenDefinitions,
    )..where((t) => t.id.equals('news_stack'))).write(
      ScreenDefinitionsCompanion(
        dataKey: const Value('news'),
        screenType: const Value('rss_article_stack'),
        configJson: const Value(
          '{"minReadMs":12000,"imagePanelFraction":0.32,"qrLogicalSize":112,"summaryCapacityCharsPerSlot":320}',
        ),
        configJsonSchema: Value(
          screenConfigJsonDocForType('rss_article_stack').schema,
        ),
        exampleConfigJson: Value(
          screenConfigJsonDocForType('rss_article_stack').example,
        ),
      ),
    );
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'news_stack',
          name: 'News (stack of 2)',
          description: const Value(
            'Two RSS stories stacked: top image right + QR left, '
            'bottom image left + QR right; title and summary between',
          ),
          screenType: 'rss_article_stack',
          configJson: const Value(
            '{"minReadMs":12000,"imagePanelFraction":0.32,"qrLogicalSize":112,"summaryCapacityCharsPerSlot":320}',
          ),
          configJsonSchema: Value(
            screenConfigJsonDocForType('rss_article_stack').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('rss_article_stack').example,
          ),
          dwellSeconds: const Value(16),
          dataKey: const Value('news'),
        ),
      );
}

Future<void> _ensureClockDataKeyLimit(AppDatabase db) async {
  await db
      .into(db.curatorDataKeyProgramLimits)
      .insertOnConflictUpdate(
        CuratorDataKeyProgramLimitsCompanion.insert(
          dataKey: 'clock',
          minPlacementsPerProgram: const Value(1),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureClockDigitalScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('clock_digital'))).getSingleOrNull();
  if (row != null) {
    await (db.update(
      db.screenDefinitions,
    )..where((t) => t.id.equals('clock_digital'))).write(
      ScreenDefinitionsCompanion(
        dataKey: const Value('clock'),
        minPlacementsPerProgram: const Value(0),
        maxPlacementsPerProgram: const Value(1),
        configJsonSchema: Value(
          screenConfigJsonDocForType('digital_clock').schema,
        ),
        exampleConfigJson: Value(
          screenConfigJsonDocForType('digital_clock').example,
        ),
      ),
    );
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'clock_digital',
          name: 'Digital clock',
          description: const Value('Local time and date'),
          screenType: 'digital_clock',
          configJson: const Value('{}'),
          configJsonSchema: Value(
            screenConfigJsonDocForType('digital_clock').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('digital_clock').example,
          ),
          dwellSeconds: const Value(16),
          dataKey: const Value('clock'),
          minPlacementsPerProgram: const Value(0),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureClockAnalogScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('clock_analog'))).getSingleOrNull();
  if (row != null) {
    await (db.update(
      db.screenDefinitions,
    )..where((t) => t.id.equals('clock_analog'))).write(
      ScreenDefinitionsCompanion(
        dataKey: const Value('clock'),
        minPlacementsPerProgram: const Value(0),
        maxPlacementsPerProgram: const Value(1),
        configJsonSchema: Value(
          screenConfigJsonDocForType('analog_clock').schema,
        ),
        exampleConfigJson: Value(
          screenConfigJsonDocForType('analog_clock').example,
        ),
      ),
    );
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'clock_analog',
          name: 'Analog clock',
          description: const Value('Analog dial with local date'),
          screenType: 'analog_clock',
          configJson: const Value('{}'),
          configJsonSchema: Value(
            screenConfigJsonDocForType('analog_clock').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('analog_clock').example,
          ),
          dwellSeconds: const Value(16),
          dataKey: const Value('clock'),
          minPlacementsPerProgram: const Value(0),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureCalendarScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('calendar'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'calendar',
          name: 'Calendar',
          description: const Value(
            'Month view with upcoming events; increase dwell_seconds when many events need air time',
          ),
          screenType: 'calendar_month',
          configJson: const Value('{}'),
          configJsonSchema: Value(
            screenConfigJsonDocForType('calendar_month').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('calendar_month').example,
          ),
          dwellSeconds: const Value(22),
          dataKey: const Value('calendar'),
          minPlacementsPerProgram: const Value(1),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureLocalApiScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('dev_local_api'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'dev_local_api',
          name: 'Developer — Local API',
          description: const Value(
            'Loopback REST base URL and API key hint; enable when configuring deployments',
          ),
          enabled: const Value(false),
          screenType: 'local_api',
          configJson: const Value('{}'),
          configJsonSchema: Value(
            screenConfigJsonDocForType('local_api').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('local_api').example,
          ),
          dwellSeconds: const Value(16),
          dataKey: const Value('dev_local_api'),
          minPlacementsPerProgram: const Value(0),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureAdminSetupScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('admin_setup'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'admin_setup',
          name: 'Setup Admin Access',
          description: const Value(
            'Onboarding URL, QR code, and bootstrap password for first login',
          ),
          enabled: const Value(true),
          screenType: 'admin_setup',
          configJson: const Value('{}'),
          configJsonSchema: Value(
            screenConfigJsonDocForType('admin_setup').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('admin_setup').example,
          ),
          dwellSeconds: const Value(18),
          frequencyWeight: const Value(200),
          minGapBetweenShowsSeconds: const Value(0),
          dataKey: const Value('admin_setup'),
          minPlacementsPerProgram: const Value(0),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureWeatherScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('weather'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'weather',
          name: 'Weather',
          description: const Value('Current weather'),
          screenType: 'weather',
          configJson: const Value('{"locationId":"salt_lake_city_ut"}'),
          configJsonSchema: Value(
            screenConfigJsonDocForType('weather').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('weather').example,
          ),
          dwellSeconds: const Value(14),
          dataKey: const Value('weather'),
          minPlacementsPerProgram: const Value(1),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureProviderRow(
  AppDatabase db, {
  required String id,
  required String providerType,
  required int pollSeconds,
}) async {
  final row = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType(providerType);
  await db
      .into(db.providerSettings)
      .insert(
        ProviderSettingsCompanion.insert(
          id: id,
          providerType: providerType,
          enabled: const Value(true),
          pollSeconds: Value(pollSeconds),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensureJokesProviderRow(AppDatabase db) async {
  final row = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals('jokes'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final jokesDoc = providerConfigJsonDocForType('jokes');
  await db
      .into(db.providerSettings)
      .insert(
        ProviderSettingsCompanion.insert(
          id: 'jokes',
          providerType: 'jokes',
          enabled: const Value(true),
          pollSeconds: const Value(3600),
          configJson: const Value(
            '{"jokesPerDay":10,"maxJokesPerTwoHours":20,"twoHourWindowMs":7200000,'
            '"jokeRetentionDays":14,"model":"gpt-4o-mini",'
            '"globalPrompt":"You write original, family-friendly jokes."}',
          ),
          configJsonSchema: Value(jokesDoc.schema),
          exampleConfigJson: Value(jokesDoc.example),
        ),
      );
}

Future<void> _ensureTriviaProviderRow(AppDatabase db) async {
  final row = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals('trivia'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final triviaDoc = providerConfigJsonDocForType('trivia');
  await db
      .into(db.providerSettings)
      .insert(
        ProviderSettingsCompanion.insert(
          id: 'trivia',
          providerType: 'trivia',
          enabled: const Value(true),
          pollSeconds: const Value(3600),
          configJson: const Value(
            '{"maxQuestionPerDay":200,"maxQuestionPerHour":20,'
            '"twoHourWindowMs":3600000,"questionRetentionDays":15,'
            '"model":"gpt-4o-mini"}',
          ),
          configJsonSchema: Value(triviaDoc.schema),
          exampleConfigJson: Value(triviaDoc.example),
        ),
      );
}

Future<void> _ensureOpenTdbTriviaProviderRow(AppDatabase db) async {
  final row = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals('opentdb_trivia'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('opentdb_trivia');
  await db
      .into(db.providerSettings)
      .insert(
        ProviderSettingsCompanion.insert(
          id: 'opentdb_trivia',
          providerType: 'opentdb_trivia',
          enabled: const Value(false),
          pollSeconds: const Value(3600),
          baseUrl: const Value('https://opentdb.com/api.php'),
          configJson: const Value(
            '{"amount":10,"questionType":"multiple","categoryMap":{"science":17,"history":23}}',
          ),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensureWeatherProviderRow(AppDatabase db) async {
  final row = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals('weather'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final weatherDoc = providerConfigJsonDocForType('weather');
  await db
      .into(db.providerSettings)
      .insert(
        ProviderSettingsCompanion.insert(
          id: 'weather',
          providerType: 'weather',
          enabled: const Value(true),
          pollSeconds: const Value(900),
          baseUrl: const Value('https://api.openweathermap.org'),
          configJson: const Value(
            '{"units":"imperial","lang":"en","hourlyCount":6,'
            '"defaultLocation":{"name":"Default","lat":40.7128,"lon":-74.0060}}',
          ),
          configJsonSchema: Value(weatherDoc.schema),
          exampleConfigJson: Value(weatherDoc.example),
        ),
      );
}

Future<void> _ensureNwsWeatherAlertsProviderRow(AppDatabase db) async {
  final row = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals('nws_weather_alerts'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('nws_weather_alerts');
  await db
      .into(db.providerSettings)
      .insert(
        ProviderSettingsCompanion.insert(
          id: 'nws_weather_alerts',
          providerType: 'nws_weather_alerts',
          enabled: const Value(true),
          pollSeconds: const Value(900),
          baseUrl: const Value('https://api.weather.gov'),
          configJson: const Value(
            '{"userAgent":"(waddle-display, operator@example.com)",'
            '"defaultLocation":{"name":"Default","lat":40.7128,"lon":-74.0060}}',
          ),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensureMicrosoftGraphClientIdKv(AppDatabase db) async {
  final row =
      await (db.select(db.configKeyValues)
            ..where((t) => t.key.equals(kMicrosoftGraphClientIdKvKey)))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.configKeyValues)
      .insert(
        ConfigKeyValuesCompanion.insert(
          key: kMicrosoftGraphClientIdKvKey,
          value: kDefaultMicrosoftGraphClientId,
        ),
      );
}

Future<void> _ensureGoogleClientIdKv(AppDatabase db) async {
  final row = await (db.select(
    db.configKeyValues,
  )..where((t) => t.key.equals(kGoogleClientIdKvKey))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.configKeyValues)
      .insert(
        ConfigKeyValuesCompanion.insert(
          key: kGoogleClientIdKvKey,
          value: kDefaultGoogleClientId,
        ),
      );
}

Future<void> _ensureGoogleCalendarProviderRow(AppDatabase db) async {
  final row = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals('google_calendar'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('google_calendar');
  await db
      .into(db.providerSettings)
      .insert(
        ProviderSettingsCompanion.insert(
          id: 'google_calendar',
          providerType: 'google_calendar',
          enabled: const Value(false),
          pollSeconds: const Value(3600),
          baseUrl: const Value('https://www.googleapis.com/calendar/v3'),
          configJson: const Value(
            '{"accounts":[],"pastDays":14,"futureDays":14}',
          ),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensureOutlookCalendarProviderRow(AppDatabase db) async {
  final row = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals('outlook_calendar'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final outlookDoc = providerConfigJsonDocForType('outlook_calendar');
  await db
      .into(db.providerSettings)
      .insert(
        ProviderSettingsCompanion.insert(
          id: 'outlook_calendar',
          providerType: 'outlook_calendar',
          enabled: const Value(false),
          pollSeconds: const Value(3600),
          baseUrl: const Value('https://graph.microsoft.com/v1.0'),
          configJson: const Value(
            '{"accounts":[],"pastDays":14,"futureDays":14}',
          ),
          configJsonSchema: Value(outlookDoc.schema),
          exampleConfigJson: Value(outlookDoc.example),
        ),
      );
}

Future<void> _ensureOneDriveMediaProviderRow(AppDatabase db) async {
  final row = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals('onedrive_media'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('onedrive_media');
  await db
      .into(db.providerSettings)
      .insert(
        ProviderSettingsCompanion.insert(
          id: 'onedrive_media',
          providerType: 'onedrive_media',
          enabled: const Value(false),
          pollSeconds: const Value(3600),
          baseUrl: const Value('https://graph.microsoft.com/v1.0'),
          configJson: const Value('{"accounts":[],"globalPerPollLimit":50}'),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensureFlickrMediaProviderRow(AppDatabase db) async {
  final row = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals('flickr_media'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('flickr_media');
  await db
      .into(db.providerSettings)
      .insert(
        ProviderSettingsCompanion.insert(
          id: 'flickr_media',
          providerType: 'flickr_media',
          enabled: const Value(false),
          pollSeconds: const Value(3600),
          baseUrl: const Value('https://api.flickr.com/services/rest'),
          configJson: const Value(
            '{"groupIds":[],"category":"flickr","perPollLimit":20,"sort":"date-posted-desc"}',
          ),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensureBingImageOfDayProviderRow(AppDatabase db) async {
  final row = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals('bing_iotd'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('bing_iotd');
  await db
      .into(db.providerSettings)
      .insert(
        ProviderSettingsCompanion.insert(
          id: 'bing_iotd',
          providerType: 'bing_iotd',
          enabled: const Value(true),
          pollSeconds: const Value(3600),
          baseUrl: const Value('https://www.bing.com'),
          configJson: const Value(
            '{"retentionDays":1,"market":"en-US","resolution":"UHD","category":"bing"}',
          ),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensurePexelsProviderRow(AppDatabase db) async {
  final row = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals('pexels'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final pexelsDoc = providerConfigJsonDocForType('pexels');
  await db
      .into(db.providerSettings)
      .insert(
        ProviderSettingsCompanion.insert(
          id: 'pexels',
          providerType: 'pexels',
          enabled: const Value(true),
          pollSeconds: const Value(1800),
          baseUrl: const Value('https://api.pexels.com'),
          configJson: const Value(
            '{"maxPhotos":100,"maxVideos":100,"photosPerHour":2,"videosPerHour":2,'
            '"minVideoSeconds":5,"maxVideoSeconds":29,"sources":['
            '{"query":"Nature","category":"nature"},'
            '{"query":"Flowers","category":"flowers"},'
            '{"query":"Landscape","category":"landscape"},'
            '{"query":"Beach","category":"beach"},'
            '{"query":"Mountains","category":"mountains"},'
            '{"query":"Motivational","category":"motivational"},'
            '{"query":"Aquarium","category":"aquarium"}]}',
          ),
          configJsonSchema: Value(pexelsDoc.schema),
          exampleConfigJson: Value(pexelsDoc.example),
        ),
      );
}

Future<void> _ensureStocksProviderRow(AppDatabase db) async {
  final row = await (db.select(
    db.providerSettings,
  )..where((t) => t.id.equals('stocks'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final stocksDoc = providerConfigJsonDocForType('stocks');
  await db
      .into(db.providerSettings)
      .insert(
        ProviderSettingsCompanion.insert(
          id: 'stocks',
          providerType: 'stocks',
          enabled: const Value(true),
          pollSeconds: const Value(300),
          baseUrl: const Value('https://finnhub.io'),
          configJson: const Value(
            '{"maxSymbolsPerCollect":25,"defaultSymbols":['
            '{"symbol":"AAPL","displayName":"Apple"},'
            '{"symbol":"MSFT","displayName":"Microsoft"},'
            '{"symbol":"GOOG","displayName":"Alphabet"},'
            '{"symbol":"NVDA","displayName":"NVIDIA"},'
            '{"symbol":"AMZN","displayName":"Amazon"}'
            '{"symbol":"TSLA","displayName":"Tesla"},'
            '{"symbol":"META","displayName":"Meta"},'
            '{"symbol":"NFLX","displayName":"Netflix"},'
            '{"symbol":"DIS","displayName":"Disney"},'
            '{"symbol":"IBM","displayName":"IBM"},'
            '{"symbol":"CSCO","displayName":"Cisco"},'
            '{"symbol":"INTC","displayName":"Intel"},'
            '{"symbol":"ORCL","displayName":"Oracle"},'
            '{"symbol":"VOO","displayName":"Vanguard S&P 500 ETF"},'
            '{"symbol":"SPY","displayName":"SPDR S&P 500 ETF"},'
            '{"symbol":"QQQ","displayName":"Invesco QQQ Trust"},'
            '{"symbol":"IWM","displayName":"iShares Russell 2000 ETF"},'
            ']}',
          ),
          configJsonSchema: Value(stocksDoc.schema),
          exampleConfigJson: Value(stocksDoc.example),
        ),
      );
}

/// Idempotent default symbol list (AAPL/MSFT enabled, the rest disabled to
/// limit API hits). Operators can toggle [StockSymbols.enabled] from the admin
/// surface without touching the provider config.
Future<void> _ensureDefaultStockSymbols(AppDatabase db) async {
  Future<void> ensure(
    String id,
    String symbol,
    String displayName, {
    required bool enabled,
  }) async {
    final existing = await (db.select(
      db.stockSymbols,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing != null) {
      return;
    }
    await db
        .into(db.stockSymbols)
        .insert(
          StockSymbolsCompanion.insert(
            id: id,
            symbol: symbol,
            displayName: Value(displayName),
            enabled: Value(enabled),
          ),
        );
  }

  await ensure('aapl', 'AAPL', 'Apple', enabled: true);
  await ensure('msft', 'MSFT', 'Microsoft', enabled: true);
  await ensure('goog', 'GOOG', 'Alphabet', enabled: true);
  await ensure('nvda', 'NVDA', 'NVIDIA', enabled: true);
  await ensure('amzn', 'AMZN', 'Amazon', enabled: false);
  await ensure('tsla', 'TSLA', 'Tesla', enabled: false);
  await ensure('meta', 'META', 'Meta', enabled: false);
  await ensure('nflx', 'NFLX', 'Netflix', enabled: false);
  await ensure('dis', 'DIS', 'Disney', enabled: false);
  await ensure('ibm', 'IBM', 'IBM', enabled: false);
  await ensure('csco', 'CSCO', 'Cisco', enabled: false);
  await ensure('intc', 'INTC', 'Intel', enabled: false);
  await ensure('orcl', 'ORCL', 'Oracle', enabled: false);
  await ensure('voo', 'VOO', 'Vanguard S&P 500 ETF', enabled: true);
  await ensure('spy', 'SPY', 'SPDR S&P 500 ETF', enabled: true);
  await ensure('qqq', 'QQQ', 'Invesco QQQ Trust', enabled: false);
  await ensure('iwm', 'IWM', 'iShares Russell 2000 ETF', enabled: false);
}

Future<void> _ensureStockQuotesScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('stock_quotes'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'stock_quotes',
          name: 'Stock quotes',
          description: const Value('Latest Finnhub quotes for enabled symbols'),
          enabled: const Value(false),
          screenType: 'stock_quotes',
          configJson: const Value('{}'),
          configJsonSchema: Value(
            screenConfigJsonDocForType('stock_quotes').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('stock_quotes').example,
          ),
          dwellSeconds: const Value(14),
          dataKey: const Value('stocks'),
        ),
      );
}

Future<void> _ensurePexelsPhotoScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('pexels_photo'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'pexels_photo',
          name: 'Pexels photo',
          description: const Value('Curated / search photos from Pexels'),
          enabled: const Value(false),
          screenType: 'pexels_photo',
          configJson: const Value('{}'),
          configJsonSchema: Value(
            screenConfigJsonDocForType('pexels_photo').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('pexels_photo').example,
          ),
          dwellSeconds: const Value(12),
          dataKey: const Value('pexels_photo'),
        ),
      );
}

Future<void> _ensurePexelsVideoScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screenDefinitions,
  )..where((t) => t.id.equals('pexels_video'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screenDefinitions)
      .insert(
        ScreenDefinitionsCompanion.insert(
          id: 'pexels_video',
          name: 'Pexels video',
          description: const Value('Popular / search videos from Pexels'),
          enabled: const Value(false),
          screenType: 'pexels_video',
          configJson: const Value('{"loop":true,"unmuted":false}'),
          configJsonSchema: Value(
            screenConfigJsonDocForType('pexels_video').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('pexels_video').example,
          ),
          dwellSeconds: const Value(25),
          dataKey: const Value('pexels_video'),
        ),
      );
}

Future<void> _ensurePhotoCollageScreens(AppDatabase db) async {
  Future<void> ensureOne({
    required String id,
    required String name,
    required String template,
    int dwellSeconds = 18,
  }) async {
    final row = await (db.select(
      db.screenDefinitions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row != null) {
      return;
    }
    final collageDoc = screenConfigJsonDocForType('pexels_photo_collage');
    await db
        .into(db.screenDefinitions)
        .insert(
          ScreenDefinitionsCompanion.insert(
            id: id,
            name: name,
            description: const Value(
              'Multi-photo collage; curator matches aspect ratio to each tile when dimensions are known',
            ),
            enabled: const Value(false),
            screenType: 'pexels_photo_collage',
            configJson: Value('{"template":"$template"}'),
            configJsonSchema: Value(collageDoc.schema),
            exampleConfigJson: Value(collageDoc.example),
            dwellSeconds: Value(dwellSeconds),
            dataKey: const Value('pexels_photo'),
          ),
        );
  }

  await ensureOne(
    id: 'photo_collage_nine_square',
    name: 'Photo collage — nine squares',
    template: kCollageTemplateNineSquareAsymmetric,
  );
  await ensureOne(
    id: 'photo_collage_eleven_hub',
    name: 'Photo collage — eleven symmetric hub',
    template: kCollageTemplateElevenSymmetricHub,
  );
  await ensureOne(
    id: 'photo_collage_nine_mixed',
    name: 'Photo collage — nine mixed',
    template: kCollageTemplateNineMixedGrid,
  );
  await ensureOne(
    id: 'photo_collage_nine_dynamic',
    name: 'Photo collage — nine dynamic hub',
    template: kCollageTemplateNineDynamicHub,
  );
  await ensureOne(
    id: 'photo_collage_twelve_circle',
    name: 'Photo collage — twelve + circle',
    template: kCollageTemplateTwelveCircleBand,
  );
}

Future<void> _ensureDefaultWeatherLocations(AppDatabase db) async {
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'salt_lake_city_ut',
          name: 'Salt Lake City, UT',
          latitude: 40.7608,
          longitude: -111.8910,
          enabled: const Value(true),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'atlanta_ga',
          name: 'Atlanta, GA',
          latitude: 33.7490,
          longitude: -84.3880,
          enabled: const Value(true),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'sandiego_ca',
          name: 'San Diego, CA',
          latitude: 32.7157,
          longitude: -117.1611,
          enabled: const Value(false),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'miami_fl',
          name: 'Miami, FL',
          latitude: 25.7617,
          longitude: -80.1918,
          enabled: const Value(false),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'denver_co',
          name: 'Denver, CO',
          latitude: 39.7392,
          longitude: -104.9903,
          enabled: const Value(false),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'las_vegas_nv',
          name: 'Las Vegas, NV',
          latitude: 36.1699,
          longitude: -115.1398,
          enabled: const Value(false),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'phoenix_az',
          name: 'Phoenix, AZ',
          latitude: 33.4483,
          longitude: -112.0740,
          enabled: const Value(false),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'seattle_wa',
          name: 'Seattle, WA',
          latitude: 47.6062,
          longitude: -122.3321,
          enabled: const Value(false),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'washington_dc',
          name: 'Washington, DC',
          latitude: 38.8951,
          longitude: -77.0369,
          enabled: const Value(false),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'boston_ma',
          name: 'Boston, MA',
          latitude: 42.3601,
          longitude: -71.0589,
          enabled: const Value(false),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'chicago_il',
          name: 'Chicago, IL',
          latitude: 41.8781,
          longitude: -87.6298,
          enabled: const Value(false),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'houston_tx',
          name: 'Houston, TX',
          latitude: 29.7604,
          longitude: -95.3698,
          enabled: const Value(false),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'austin_tx',
          name: 'Austin, TX',
          latitude: 30.2672,
          longitude: -97.7431,
          enabled: const Value(false),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'san_francisco_ca',
          name: 'San Francisco, CA',
          latitude: 37.7749,
          longitude: -122.4194,
          enabled: const Value(false),
        ),
      );
  await db
      .into(db.weatherLocations)
      .insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'new_york_ny',
          name: 'New York, NY',
          latitude: 40.7128,
          longitude: -74.0060,
          enabled: const Value(false),
        ),
      );
}
