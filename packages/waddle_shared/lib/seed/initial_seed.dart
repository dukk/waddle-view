import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:waddle_shared/alerts/alert_severity_icons_kv.dart';
import 'package:waddle_shared/layout/collage_template_ids.dart';
import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_floating_balloons_settings.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/tables/config_key_values_seed.dart';
import 'package:waddle_shared/theme/display_text_scale_kv.dart';
import 'package:waddle_shared/theme/display_program_history_kv.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';
import 'package:waddle_shared/persistence/reject_term_defaults.dart';
import 'tables/content_categories_seed.dart';
import 'tables/interests_jokes_seed.dart';
import 'tables/integrations_seed.dart';
import 'tables/interests_locations_seed.dart';
import 'tables/interests_rss_feeds_seed.dart';
import 'tables/interests_trivia_seed.dart';
import 'tables/curator_configurations_seed.dart';
import 'tables/overlay_types_seed.dart';
import 'tables/screen_types_seed.dart';
import 'tables/ticker_tape_types_seed.dart';

/// Idempotent demo rows for integrations, screens, ticker tapes, and related defaults.
Future<void> ensureInitialSeed(AppDatabase db) async {
  await ensureIntegrationsDefaults(db);
  await _ensureDefaultInterestsStockSymbols(db);
  await ensureDefaultInterestsLocations(db);
  await ensureDefaultContentCategories(db);
  await ensureDefaultRejectTerms(db);
  await ensureDefaultInterestsJokes(db);
  await ensureDefaultInterestsTrivia(db);
  await ensureDefaultInterestsRssFeeds(db);
  await _ensureTickerTapes(db);
  await _ensureDisplayThemeKv(db);
  await _ensureDisplayTimezoneKv(db);
  await _ensureDisplayTextScaleKv(db);
  await _ensureDisplayProgramHistoryDepthKv(db);
  await ensureControllerDatetimeFormatKvs(db);
  await _ensureAlertSeverityIconsKv(db);
  await ensureOverlayTypes(db);
  await _ensureDefaultRainingHeartsOverlay(db);
  await _ensureDefaultBirthdayConfettiOverlay(db);
  await _ensureDefaultFloatingBalloonsOverlay(db);
  await _ensureDefaultWattleViewsBirthdayMessageOverlay(db);
  await _ensureDefaultFallingDucksOverlay(db);
  await ensureScreenTypes(db);
  await _ensureWelcomeScreen(db);
  await _ensureJokeScreen(db);
  await _ensureTriviaScreen(db);
  await _ensureGuestWifiScreen(db);
  await _ensureNewsScreen(db);
  await _ensureNewsRightImageScreen(db);
  await _ensureNewsColumnsScreen(db);
  await _ensureNewsStackScreen(db);
  await _ensureNewsGridScreen(db);
  await _ensureClockDataKeyLimit(db);
  await _ensureClockDigitalScreen(db);
  await _ensureClockAnalogScreen(db);
  await _ensureCalendarScreen(db);
  await _ensureLocalApiScreen(db);
  await _ensureDataHealthScreen(db);
  await _ensureGeneralOpenAiDemoScreen(db);
  await _ensureAdminSetupScreen(db);
  await _ensureWeatherScreen(db);
  await _ensurePhotoScreen(db);
  await _ensureVideoScreen(db);
  await _ensurePhotoCollageScreens(db);
  await _ensureStockQuotesScreen(db);
  await _ensureSleepMessageScreen(db);
  await _ensureControllerInviteScreen(db);
  await ensureDefaultCuratorConfigurations(db);
}

Future<void> _seedOverlayIfMissing(
  AppDatabase db, {
  required String id,
  required String overlayType,
  required String label,
  required String configJson,
}) {
  return db
      .into(db.overlays)
      .insert(
        OverlaysCompanion.insert(
          id: id,
          overlayType: overlayType,
          label: Value(label),
          configJson: Value(configJson),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

Future<void> _ensureDefaultRainingHeartsOverlay(AppDatabase db) async {
  final configJson = jsonEncode(<String, Object?>{
    'shapes': <String>['heart', 'raindrop', 'cat', 'dog'],
  });
  await _seedOverlayIfMissing(
    db,
    id: kDefaultMothersDayOverlayId,
    overlayType: kOverlayTypeShapeRain,
    label: 'Raining Hearts',
    configJson: configJson,
  );
}

Future<void> _ensureDefaultBirthdayConfettiOverlay(AppDatabase db) async {
  final configJson = jsonEncode(<String, Object?>{
    'colors': <String>['#E53935', '#FFEB3B', '#00BCD4', '#E91E63'],
    'density': 0.36,
    'fall_speed': 0.12,
    'opacity': 0.48,
  });
  await _seedOverlayIfMissing(
    db,
    id: kDefaultBirthdayConfettiOverlayId,
    overlayType: kOverlayTypeBirthdayConfetti,
    label: 'Default Birthday Confetti',
    configJson: configJson,
  );
}

Future<void> _ensureDefaultFloatingBalloonsOverlay(AppDatabase db) async {
  final configJson = jsonEncode(<String, Object?>{
    'colors': kFloatingBalloonsDefaultColorHexes,
    'spawn_interval_sec': 22,
    'rise_speed': 85,
    'max_active': 6,
    'cluster_chance': 0.4,
    'balloon_scale': 0.09,
    'scale_jitter': 0.25,
    'opacity': 0.92,
  });
  await _seedOverlayIfMissing(
    db,
    id: kDefaultFloatingBalloonsOverlayId,
    overlayType: kOverlayTypeFloatingBalloons,
    label: 'Default Floating Balloons',
    configJson: configJson,
  );
}

Future<void> _ensureDefaultFallingDucksOverlay(AppDatabase db) async {
  final configJson = jsonEncode(<String, Object?>{
    'image_blob_keys': kSeededDuckOverlayBlobKeys,
    'drop_interval_sec': 45,
    'fall_speed': 194,
    'image_scale': 0.12,
    'scale_jitter': 0.33,
  });
  await _seedOverlayIfMissing(
    db,
    id: kDefaultFallingDucksOverlayId,
    overlayType: kOverlayTypeFallingImages,
    label: 'Default Falling Ducks',
    configJson: configJson,
  );
}

Future<void> _ensureDefaultWattleViewsBirthdayMessageOverlay(
  AppDatabase db,
) async {
  final configJson = jsonEncode(<String, Object?>{
    'messages': <String>[kDefaultBouncingMessageOverlayPhrase],
    'color': '#5C6BC0',
    'font_size': 40,
    'font_weight': 700,
    'letter_spacing': 0.8,
    'shadow': true,
    'speed': 0.95,
  });
  await _seedOverlayIfMissing(
    db,
    id: kDefaultWattleViewsBirthdayMessageOverlayId,
    overlayType: kOverlayTypeBouncingMessage,
    label: "Wattle View's Birthday Message!",
    configJson: configJson,
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

Future<void> _ensureDisplayProgramHistoryDepthKv(AppDatabase db) async {
  final row =
      await (db.select(db.configKeyValues)
            ..where((t) => t.key.equals(kDisplayProgramHistoryDepthKvKey)))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.configKeyValues)
      .insert(
        ConfigKeyValuesCompanion.insert(
          key: kDisplayProgramHistoryDepthKvKey,
          value: '$kDefaultDisplayProgramHistoryDepth',
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
    await db
        .into(db.tickerTapes)
        .insertOnConflictUpdate(
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
    final r = await (db.select(
      db.tickerTapes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (r == null) {
      return;
    }
    final raw = r.configJson.trim();
    if (raw.isNotEmpty && raw != '{}') {
      return;
    }
    await (db.update(db.tickerTapes)..where((t) => t.id.equals(id))).write(
      TickerTapesCompanion(configJson: Value(jsonEncode({'text': text}))),
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
    label: 'Stocks',
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
          label: 'Welcome',
          description: const Value('Demo display screen'),
          screenType: 'static_text',
          configJson: const Value('{"text":"Welcome to Waddle View"}'),
          minDwellSeconds: const Value(8),
          maxDwellSeconds: const Value(14),
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
          label: 'Jokes',
          description: const Value('Random joke with delayed punchline'),
          screenType: 'joke',
          configJson: const Value('{}'),
          minDwellSeconds: const Value(18),
          maxDwellSeconds: const Value(24),
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
          label: 'Trivia',
          description: const Value(
            'Trivia with progress reveal and strike-out wrong answers (multiple-choice + true/false)',
          ),
          screenType: 'trivia',
          configJson: const Value('{}'),
          minDwellSeconds: const Value(14),
          maxDwellSeconds: const Value(20),
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
          label: 'Guest WiFi',
          description: const Value('QR and credentials for guest network'),
          screenType: 'wifi',
          configJson: const Value('{}'),
          minDwellSeconds: const Value(16),
          maxDwellSeconds: const Value(22),
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
    await (db.update(db.screens)..where((t) => t.id.equals('news'))).write(
      ScreensCompanion(
        dataKey: const Value('news'),
        maxPlacementsPerProgram: const Value(null),
        minPlacementsPerProgram: const Value(1),
        screenType: const Value('news'),
        configJson: const Value(
          '{"scrollDelayMs":2500,"trailingHoldMs":2000,"scrollPixelsPerSecond":48,"minReadMs":8000,"summaryCapacityChars":1200}',
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
          label: 'News',
          description: const Value(
            'RSS story with image and scrolling summary',
          ),
          screenType: 'news',
          configJson: const Value(
            '{"scrollDelayMs":2500,"trailingHoldMs":2000,"scrollPixelsPerSecond":48,"minReadMs":8000,"summaryCapacityChars":1200}',
          ),
          minDwellSeconds: const Value(10),
          maxDwellSeconds: const Value(16),
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
        screenType: const Value('news'),
        configJson: const Value(
          '{"scrollDelayMs":2500,"trailingHoldMs":2000,"scrollPixelsPerSecond":48,"minReadMs":8000,"imageOnRight":true,"summaryCapacityChars":1200}',
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
          label: 'News (image right)',
          description: const Value(
            'RSS story with image on the right and scrolling summary',
          ),
          screenType: 'news',
          configJson: const Value(
            '{"scrollDelayMs":2500,"trailingHoldMs":2000,"scrollPixelsPerSecond":48,"minReadMs":8000,"imageOnRight":true,"summaryCapacityChars":1200}',
          ),
          minDwellSeconds: const Value(10),
          maxDwellSeconds: const Value(16),
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
        screenType: const Value('news_columns'),
        configJson: const Value(
          '{"columnCount":3,"minReadMs":10000,"summaryCapacityCharsPerColumn":220}',
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
          label: 'News (3 columns)',
          description: const Value(
            'Three RSS stories: image above title and summary in each column',
          ),
          screenType: 'news_columns',
          configJson: const Value(
            '{"columnCount":3,"minReadMs":10000,"summaryCapacityCharsPerColumn":220}',
          ),
          minDwellSeconds: const Value(14),
          maxDwellSeconds: const Value(20),
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
        screenType: const Value('news_stack'),
        configJson: const Value(
          '{"minReadMs":12000,"imagePanelFraction":0.32,"qrLogicalSize":112,"summaryCapacityCharsPerSlot":320}',
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
          label: 'News (stack of 2)',
          description: const Value(
            'Two RSS stories stacked: top image right + QR left, '
            'bottom image left + QR right; title and summary between',
          ),
          screenType: 'news_stack',
          configJson: const Value(
            '{"minReadMs":12000,"imagePanelFraction":0.32,"qrLogicalSize":112,"summaryCapacityCharsPerSlot":320}',
          ),
          minDwellSeconds: const Value(14),
          maxDwellSeconds: const Value(20),
          dataKey: const Value('news'),
        ),
      );
}

Future<void> _ensureNewsGridScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screens,
  )..where((t) => t.id.equals('news_grid'))).getSingleOrNull();
  if (row != null) {
    await (db.update(db.screens)..where((t) => t.id.equals('news_grid'))).write(
      ScreensCompanion(
        dataKey: const Value('news'),
        screenType: const Value('news_grid'),
        configJson: const Value(
          '{"showSummary":false,"minReadMs":10000,"qrMode":"hidden",'
          '"qrLogicalSize":52,"imageFit":"cover"}',
        ),
      ),
    );
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
          id: 'news_grid',
          label: 'News (3×2 grid)',
          description: const Value(
            'Six RSS stories in a 3×2 grid: image, headline, and source per cell; '
            'optional summary and QR on the left or right of each image',
          ),
          screenType: 'news_grid',
          configJson: const Value(
            '{"showSummary":false,"minReadMs":10000,"qrMode":"hidden",'
            '"qrLogicalSize":52,"imageFit":"cover"}',
          ),
          minDwellSeconds: const Value(14),
          maxDwellSeconds: const Value(20),
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
      ),
    );
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
          id: 'clock_digital',
          label: 'Digital clock',
          description: const Value('Local time and date'),
          screenType: 'digital_clock',
          configJson: const Value('{}'),
          minDwellSeconds: const Value(14),
          maxDwellSeconds: const Value(20),
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
      ),
    );
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
          id: 'clock_analog',
          label: 'Analog clock',
          description: const Value('Analog dial with local date'),
          screenType: 'analog_clock',
          configJson: const Value('{}'),
          minDwellSeconds: const Value(14),
          maxDwellSeconds: const Value(20),
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
          label: 'Calendar',
          description: const Value(
            'Month view with upcoming events; increase dwell_seconds when many events need air time',
          ),
          screenType: 'calendar_month',
          configJson: const Value('{}'),
          minDwellSeconds: const Value(20),
          maxDwellSeconds: const Value(26),
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
          label: 'Developer — Local API',
          description: const Value(
            'Loopback REST base URL and API key hint; enable when configuring deployments',
          ),
          screenType: 'local_api',
          configJson: const Value('{}'),
          minDwellSeconds: const Value(14),
          maxDwellSeconds: const Value(20),
          dataKey: const Value('dev_local_api'),
          minPlacementsPerProgram: const Value(0),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureGeneralOpenAiDemoScreen(AppDatabase db) async {
  const screenId = 'dev_general_openai_dashboard';
  final row = await (db.select(
    db.screens,
  )..where((t) => t.id.equals(screenId))).getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = screenConfigJsonDocForType('general_2_column');
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
          id: screenId,
          label: 'Developer — General OpenAI dashboard',
          description: const Value(
            'Two-column KV widgets bound to default_general_openai prompt keys',
          ),
          screenType: 'general_2_column',
          configJson: Value(doc.example),
          minDwellSeconds: const Value(12),
          maxDwellSeconds: const Value(18),
          frequencyWeight: const Value(10),
          dataKey: const Value('general_openai_demo'),
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
          label: 'Developer — Data health',
          description: const Value(
            'SQLite content totals, category breakdowns, and charts; '
            'enable for operator visibility',
          ),
          screenType: 'data_health',
          configJson: const Value(
            '{"headline":"Data health","refreshIntervalSeconds":45}',
          ),
          minDwellSeconds: const Value(16),
          maxDwellSeconds: const Value(22),
          dataKey: const Value('dev_data_health'),
          minPlacementsPerProgram: const Value(0),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureSleepMessageScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screens,
  )..where((t) => t.id.equals('sleep_message'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
          id: 'sleep_message',
          label: 'Sleep reminder',
          description: const Value('Night-time rest message'),
          screenType: 'static_text',
          configJson: const Value(
            '{"text":"Everyone should get some sleep so you\'ll be rested for tomorrow."}',
          ),
          minDwellSeconds: const Value(20),
          maxDwellSeconds: const Value(30),
          maxPlacementsPerProgram: const Value(2),
        ),
      );
}

Future<void> _ensureControllerInviteScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screens,
  )..where((t) => t.id.equals('controller_invite'))).getSingleOrNull();
  if (row != null) {
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
          id: 'controller_invite',
          label: 'Controller invite',
          description: const Value('Viewer join QR for waddle_controller'),
          screenType: 'controller_invite',
          configJson: const Value(
            '{"inviteRole":"viewer","headline":"Manage this display from your phone"}',
          ),
          minDwellSeconds: const Value(25),
          maxDwellSeconds: const Value(40),
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
          label: 'Setup Admin Access',
          description: const Value(
            'Onboarding URL, QR code, and bootstrap password for first login',
          ),
          screenType: 'admin_setup',
          configJson: const Value('{}'),
          minDwellSeconds: const Value(16),
          maxDwellSeconds: const Value(22),
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
          label: 'Weather',
          description: const Value('Current weather'),
          screenType: 'weather',
          configJson: const Value('{"locationId":"new_york_ny"}'),
          minDwellSeconds: const Value(12),
          maxDwellSeconds: const Value(18),
          dataKey: const Value('weather'),
          minPlacementsPerProgram: const Value(1),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

/// Idempotent default symbol list (AAPL/MSFT enabled, the rest disabled to
/// limit API hits). Operators can toggle [StockSymbols.enabled] from the admin
/// surface without touching the provider config.
Future<void> _ensureDefaultInterestsStockSymbols(AppDatabase db) async {
  Future<void> ensure(
    String id,
    String symbol,
    String displayName, {
    required String category,
    required bool enabled,
  }) async {
    final existing = await (db.select(
      db.interestsStockSymbols,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing != null) {
      return;
    }
    await db
        .into(db.interestsStockSymbols)
        .insert(
          InterestsStockSymbolsCompanion.insert(
            id: id,
            symbol: symbol,
            displayName: Value(displayName),
            category: Value(category),
            enabled: Value(enabled),
          ),
        );
  }

  // Technology
  await ensure('aapl', 'AAPL', 'Apple', category: 'technology', enabled: true);
  await ensure(
    'msft',
    'MSFT',
    'Microsoft',
    category: 'technology',
    enabled: true,
  );
  await ensure(
    'goog',
    'GOOG',
    'Alphabet',
    category: 'technology',
    enabled: true,
  );
  await ensure('nvda', 'NVDA', 'NVIDIA', category: 'technology', enabled: true);
  await ensure('meta', 'META', 'Meta', category: 'technology', enabled: false);
  await ensure('intc', 'INTC', 'Intel', category: 'technology', enabled: false);
  await ensure('csco', 'CSCO', 'Cisco', category: 'technology', enabled: false);
  await ensure(
    'orcl',
    'ORCL',
    'Oracle',
    category: 'technology',
    enabled: false,
  );
  await ensure('ibm', 'IBM', 'IBM', category: 'technology', enabled: false);
  await ensure(
    'amzn',
    'AMZN',
    'Amazon',
    category: 'technology',
    enabled: false,
  );
  // Finance
  await ensure(
    'jpm',
    'JPM',
    'JPMorgan Chase',
    category: 'finance',
    enabled: false,
  );
  await ensure('v', 'V', 'Visa', category: 'finance', enabled: false);
  await ensure('ma', 'MA', 'Mastercard', category: 'finance', enabled: false);
  await ensure(
    'spy',
    'SPY',
    'SPDR S&P 500 ETF',
    category: 'finance',
    enabled: true,
  );
  await ensure(
    'voo',
    'VOO',
    'Vanguard S&P 500 ETF',
    category: 'finance',
    enabled: true,
  );
  await ensure(
    'qqq',
    'QQQ',
    'Invesco QQQ Trust',
    category: 'finance',
    enabled: false,
  );
  await ensure(
    'iwm',
    'IWM',
    'iShares Russell 2000 ETF',
    category: 'finance',
    enabled: false,
  );
  // Entertainment
  await ensure(
    'nflx',
    'NFLX',
    'Netflix',
    category: 'entertainment',
    enabled: false,
  );
  await ensure(
    'dis',
    'DIS',
    'Disney',
    category: 'entertainment',
    enabled: false,
  );
  // Automotive
  await ensure('tsla', 'TSLA', 'Tesla', category: 'automotive', enabled: false);
  // Health
  await ensure(
    'jnj',
    'JNJ',
    'Johnson & Johnson',
    category: 'health',
    enabled: false,
  );
  await ensure(
    'unh',
    'UNH',
    'UnitedHealth',
    category: 'health',
    enabled: false,
  );
  // General / diversified
  await ensure(
    'xom',
    'XOM',
    'Exxon Mobil',
    category: 'general',
    enabled: false,
  );
  await ensure('wmt', 'WMT', 'Walmart', category: 'general', enabled: false);
  await ensure('ko', 'KO', 'Coca-Cola', category: 'general', enabled: false);
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
          label: 'Stock quotes',
          description: const Value('Latest Finnhub quotes for enabled symbols'),
          screenType: 'stock_quotes',
          configJson: const Value('{}'),
          minDwellSeconds: const Value(12),
          maxDwellSeconds: const Value(18),
          dataKey: const Value('stocks'),
        ),
      );
}

Future<void> _ensurePhotoScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screens,
  )..where((t) => t.id.equals('photo'))).getSingleOrNull();
  if (row != null) {
    await (db.update(db.screens)..where((t) => t.id.equals('photo'))).write(
      ScreensCompanion(
        screenType: const Value('photo'),
        dataKey: const Value('photo'),
      ),
    );
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
          id: 'photo',
          label: 'Pexels photo',
          description: const Value('Curated / search photos from Pexels'),
          screenType: 'photo',
          configJson: const Value('{}'),
          minDwellSeconds: const Value(10),
          maxDwellSeconds: const Value(16),
          dataKey: const Value('photo'),
        ),
      );
}

Future<void> _ensureVideoScreen(AppDatabase db) async {
  final row = await (db.select(
    db.screens,
  )..where((t) => t.id.equals('video'))).getSingleOrNull();
  if (row != null) {
    await (db.update(db.screens)..where((t) => t.id.equals('video'))).write(
      ScreensCompanion(
        screenType: const Value('video'),
        dataKey: const Value('video'),
      ),
    );
    return;
  }
  await db
      .into(db.screens)
      .insert(
        ScreensCompanion.insert(
          id: 'video',
          label: 'Pexels video',
          description: const Value('Popular / search videos from Pexels'),
          screenType: 'video',
          configJson: const Value('{"loop":true,"unmuted":false}'),
          minDwellSeconds: const Value(23),
          maxDwellSeconds: const Value(29),
          dataKey: const Value('video'),
        ),
      );
}

Future<void> _ensurePhotoCollageScreens(AppDatabase db) async {
  Future<void> ensureOne({
    required String id,
    required String label,
    required String template,
    int dwellSeconds = 18,
  }) async {
    final row = await (db.select(
      db.screens,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row != null) {
      await (db.update(db.screens)..where((t) => t.id.equals(id))).write(
        ScreensCompanion(
          screenType: const Value('photo_collage'),
          dataKey: const Value('photo'),
        ),
      );
      return;
    }
    await db
        .into(db.screens)
        .insert(
          ScreensCompanion.insert(
            id: id,
            label: label,
            description: const Value(
              'Multi-photo collage; curator matches aspect ratio to each tile when dimensions are known',
            ),
            screenType: 'photo_collage',
            configJson: Value('{"template":"$template"}'),
            minDwellSeconds: Value(dwellSeconds),
            maxDwellSeconds: Value(dwellSeconds),
            dataKey: const Value('photo'),
          ),
        );
  }

  await ensureOne(
    id: 'photo_collage_nine_square',
    label: 'Photo collage — nine squares',
    template: kCollageTemplateNineSquareAsymmetric,
  );
  await ensureOne(
    id: 'photo_collage_eleven_hub',
    label: 'Photo collage — eleven symmetric hub',
    template: kCollageTemplateElevenSymmetricHub,
  );
  await ensureOne(
    id: 'photo_collage_nine_mixed',
    label: 'Photo collage — nine mixed',
    template: kCollageTemplateNineMixedGrid,
  );
  await ensureOne(
    id: 'photo_collage_nine_dynamic',
    label: 'Photo collage — nine dynamic hub',
    template: kCollageTemplateNineDynamicHub,
  );
  await ensureOne(
    id: 'photo_collage_twelve_circle',
    label: 'Photo collage — twelve + circle',
    template: kCollageTemplateTwelveCircleBand,
  );
}
