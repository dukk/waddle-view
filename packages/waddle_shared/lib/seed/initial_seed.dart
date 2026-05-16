import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:waddle_shared/alerts/alert_severity_icons_kv.dart';
import 'package:waddle_shared/layout/collage_template_ids.dart';
import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_sql.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/theme/display_text_scale_kv.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';
import 'tables/content_categories_seed.dart';
import 'tables/joke_categories_seed.dart';
import 'tables/integrations_seed.dart';
import 'tables/rss_feed_sources_seed.dart';
import 'tables/trivia_categories_seed.dart';

/// Idempotent demo rows for stub provider + ticker.
Future<void> ensureInitialSeed(AppDatabase db) async {
  final existing = await (db.select(
    db.integrations,
  )..where((t) => t.id.equals('stub'))).getSingleOrNull();
  if (existing == null) {
    final stubDoc = providerConfigJsonDocForType('stub');
    await db
        .into(db.integrations)
        .insert(
          IntegrationsCompanion.insert(
            id: 'stub',
            providerType: 'stub',
            enabled: const Value(true),
            pollSeconds: const Value(60),
            configJsonSchema: Value(stubDoc.schema),
            exampleConfigJson: Value(stubDoc.example),
          ),
        );
  }
  await ensureIntegrationsDefaults(db);
  await _ensureDefaultStockSymbols(db);
  await _ensureDefaultWeatherLocations(db);
  await ensureDefaultContentCategories(db);
  await ensureDefaultJokeCategories(db);
  await ensureDefaultTriviaCategories(db);
  await ensureDefaultRssNewsFeeds(db);
  await _ensureCuratorSettings(db);
  await _ensureTickerTapes(db);
  await _ensureDisplayThemeKv(db);
  await _ensureDisplayTimezoneKv(db);
  await _ensureDisplayTextScaleKv(db);
  await _ensureAlertSeverityIconsKv(db);
  await _ensureDefaultMothersDayOverlay(db);
  await _ensureDefaultBirthdayOverlayExample(db);
  await _ensureDefaultBouncingMessageOverlay(db);
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
  await _ensureDataHealthScreen(db);
  await _ensureAdminSetupScreen(db);
  await _ensureWeatherScreen(db);
  await _ensurePexelsPhotoScreen(db);
  await _ensurePexelsVideoScreen(db);
  await _ensurePhotoCollageScreens(db);
  await _ensureStockQuotesScreen(db);
}

Future<void> _ensureDefaultMothersDayOverlay(AppDatabase db) async {
  await db.customStatement(kEnsureOverlaysTableSql);
  final configJson = jsonEncode(<String, Object?>{
    'messages': <String>["Happy Mother's Day!"],
  });
  final heartsDoc = displayOverlayConfigJsonDocForType(kOverlayTypeHeartsRain);
  await db.customStatement(
    '''INSERT OR IGNORE INTO overlays (
      id,
      enabled,
      overlay_type,
      label,
      config_json,
      config_json_schema,
      example_config_json,
      repeat_annually,
      year_exact,
      start_month,
      start_day,
      end_month,
      end_day,
      nth_week_of_month,
      nth_weekday
    )
    VALUES (?, 1, ?, ?, ?, ?, ?, 1,
      NULL, 5, 1, NULL, NULL,
      2, ?)''',
    <Object?>[
      kDefaultMothersDayOverlayId,
      kOverlayTypeHeartsRain,
      "Mother's Day (US: 2nd Sunday in May)",
      configJson,
      heartsDoc.schema,
      heartsDoc.example,
      DateTime.sunday,
    ],
  );
}

Future<void> _ensureDefaultBirthdayOverlayExample(AppDatabase db) async {
  await db.customStatement(kEnsureOverlaysTableSql);
  final configJson = jsonEncode(<String, Object?>{
    'messages': <String>['Happy birthday!'],
    'shapes': <String>['rect', 'circle', 'mix'],
    'density': 0.36,
    'fall_speed': 0.12,
    'opacity': 0.48,
    'message_interval_sec': 38,
  });
  final confettiDoc = displayOverlayConfigJsonDocForType(
    kOverlayTypeBirthdayConfetti,
  );
  await db.customStatement(
    '''INSERT OR IGNORE INTO overlays (
      id,
      enabled,
      overlay_type,
      label,
      config_json,
      config_json_schema,
      example_config_json,
      repeat_annually,
      year_exact,
      start_month,
      start_day,
      end_month,
      end_day,
      nth_week_of_month,
      nth_weekday
    )
    VALUES (?, 0, ?, ?, ?, ?, ?, 1,
      NULL, 5, 13, NULL, NULL,
      NULL, NULL)''',
    <Object?>[
      kDefaultBirthdayOverlayExampleId,
      kOverlayTypeBirthdayConfetti,
      'Example: May 13 birthday (disabled)',
      configJson,
      confettiDoc.schema,
      confettiDoc.example,
    ],
  );
}

Future<void> _ensureDefaultBouncingMessageOverlay(AppDatabase db) async {
  await db.customStatement(kEnsureOverlaysTableSql);
  final configJson = jsonEncode(<String, Object?>{
    'messages': <String>[kDefaultBouncingMessageOverlayPhrase],
    'color': '#5C6BC0',
    'font_size': 40,
    'font_weight': 700,
    'letter_spacing': 0.8,
    'shadow': true,
    'speed': 0.95,
  });
  final doc = displayOverlayConfigJsonDocForType(kOverlayTypeBouncingMessage);
  await db.customStatement(
    '''INSERT OR IGNORE INTO overlays (
      id,
      enabled,
      overlay_type,
      label,
      config_json,
      config_json_schema,
      example_config_json,
      repeat_annually,
      year_exact,
      start_month,
      start_day,
      end_month,
      end_day,
      nth_week_of_month,
      nth_weekday
    )
    VALUES (?, 0, ?, ?, ?, ?, ?, 1,
      NULL, 5, 13, NULL, NULL,
      NULL, NULL)''',
    <Object?>[
      kDefaultBouncingMessageOverlayId,
      kOverlayTypeBouncingMessage,
      'Example: May 13 bouncing message (disabled)',
      configJson,
      doc.schema,
      doc.example,
    ],
  );
}

Future<void> _ensureDisplayTimezoneKv(AppDatabase db) async {
  final row = await (db.select(
    db.configKeyValues,
  )..where((t) => t.key.equals(kDisplayTimezoneKvKey))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.configKeyValues)
      .insert(
        ConfigKeyValuesCompanion.insert(
          key: kDisplayTimezoneKvKey,
          value: kDefaultDisplayTimezoneIana,
        ),
      );
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

Future<void> _ensureTickerTapes(AppDatabase db) async {
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
    final doc = tickerSlotConfigJsonDocForType(tickerType);
    await db
        .into(db.tickerTapes)
        .insertOnConflictUpdate(
          TickerTapesCompanion.insert(
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
    name: 'Time',
    description: 'Local clock string',
    tickerType: 'time',
    sortOrder: 0,
  );
  await upsert(
    id: 'ticker_weather',
    name: 'Weather',
    description: 'Live weather; optional fallbackText in config_json',
    tickerType: 'weather',
    sortOrder: 10,
  );
  await upsert(
    id: 'ticker_news',
    name: 'News',
    description: 'RSS headlines; optional fallbackText in config_json',
    tickerType: 'news',
    sortOrder: 20,
  );
  await upsert(
    id: 'ticker_quote',
    name: 'Quote',
    description: 'Static line from config_json fallbackText',
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
    description: 'Extra ticker.marquee.* keys in config_key_values (disabled by default)',
    enabled: false,
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
    db.screens,
  )..where((t) => t.id.equals('welcome'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('jokes'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('trivia'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('guest_wifi'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
          id: 'guest_wifi',
          name: 'Guest WiFi',
          description: const Value('QR and credentials for guest network'),
          screenType: 'wifi',
          configJson: const Value('{}'),
          configJsonSchema: Value(
            screenConfigJsonDocForType('wifi').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('wifi').example,
          ),
          dwellSeconds: const Value(18),
          maxPlacementsPerProgram: const Value(1),
          dataKey: const Value('guest_wifi'),
        ),
      );
}

Future<void> _ensureNewsScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screens,
  )..where((t) => t.id.equals('news'))).getSingleOrNull();
  if (row != null) {
    await (db.update(
      db.screens,
    )..where((t) => t.id.equals('news'))).write(
      ScreensCompanion(
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
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('news_right'))).getSingleOrNull();
  if (row != null) {
    await (db.update(
      db.screens,
    )..where((t) => t.id.equals('news_right'))).write(
      ScreensCompanion(
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
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('news_columns'))).getSingleOrNull();
  if (row != null) {
    await (db.update(
      db.screens,
    )..where((t) => t.id.equals('news_columns'))).write(
      ScreensCompanion(
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
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('news_stack'))).getSingleOrNull();
  if (row != null) {
    await (db.update(
      db.screens,
    )..where((t) => t.id.equals('news_stack'))).write(
      ScreensCompanion(
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
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('clock_digital'))).getSingleOrNull();
  if (row != null) {
    await (db.update(
      db.screens,
    )..where((t) => t.id.equals('clock_digital'))).write(
      ScreensCompanion(
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
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('clock_analog'))).getSingleOrNull();
  if (row != null) {
    await (db.update(
      db.screens,
    )..where((t) => t.id.equals('clock_analog'))).write(
      ScreensCompanion(
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
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('calendar'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('dev_local_api'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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

Future<void> _ensureDataHealthScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screens,
  )..where((t) => t.id.equals('dev_data_health'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
          id: 'dev_data_health',
          name: 'Developer — Data health',
          description: const Value(
            'SQLite content totals, category breakdowns, and charts; '
            'enable for operator visibility',
          ),
          enabled: const Value(false),
          screenType: 'data_health',
          configJson: const Value(
            '{"headline":"Data health","refreshIntervalSeconds":45}',
          ),
          configJsonSchema: Value(
            screenConfigJsonDocForType('data_health').schema,
          ),
          exampleConfigJson: Value(
            screenConfigJsonDocForType('data_health').example,
          ),
          dwellSeconds: const Value(18),
          dataKey: const Value('dev_data_health'),
          minPlacementsPerProgram: const Value(0),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureAdminSetupScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screens,
  )..where((t) => t.id.equals('admin_setup'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('weather'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('stock_quotes'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('pexels_photo'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
    db.screens,
  )..where((t) => t.id.equals('pexels_video'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
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
      db.screens,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row != null) {
      return;
    }
    final collageDoc = screenConfigJsonDocForType('pexels_photo_collage');
    await db
        .into(db.screens)
        .insert(
          ScreensCompanion.insert(
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
