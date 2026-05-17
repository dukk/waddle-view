import 'dart:developer' show log;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'display_overlay_sql.dart';
import 'reject_term_defaults.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    ContentCategories,
    Integrations,
    BlobMetadata,
    Alerts,
    ConfigKeyValues,
    Screens,
    TickerTapes,
    CuratorConfigurations,
    CuratorScheduleRules,
    CuratorConfigurationMembers,
    CuratorDataKeyProgramLimits,
    InterestsRssFeeds,
    RssArticles,
    InterestsJokes,
    Jokes,
    JokeGenerationBatches,
    InterestsTrivia,
    TriviaQuestions,
    TriviaGenerationBatches,
    CalendarEvents,
    InterestsLocations,
    WeatherCurrent,
    WeatherAlerts,
    Photos,
    Videos,
    PexelsFetchBatches,
    InterestsStockSymbols,
    StockQuotes,
    InterestsHomeAssistantEntities,
    HomeAssistantEntityStates,
    RejectTerms,
    AdoptionPending,
    ApiClients,
    CorsAllowedOrigins,
    IntegrationSecrets,
    SecretStoreMeta,
    InstalledPlugins,
    RuntimeSignals,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await customStatement('''
CREATE VIEW IF NOT EXISTS v_alert_active_candidates AS
SELECT *
FROM alerts
WHERE dismissed_at IS NULL
ORDER BY priority DESC, created_at DESC;
''');
      await customStatement(kEnsureOverlaysTableSql);
      await _seedDefaultRejectTerms(this);
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from == 1 && to >= 2) {
        await _migrateV1ToV2InterestsTableRenames(this);
        if (to == 2) {
          return;
        }
        from = 2;
      }
      if (from == 2 && to >= 3) {
        await _migrateV2ToV3IntegrationSecrets(this, m);
        if (to == 3) {
          return;
        }
        from = 3;
      }
      if (from == 3 && to >= 4) {
        await _migrateV3ToV4PluginRuntime(this, m);
        if (to == 4) {
          return;
        }
        from = 4;
      }
      if (from == 4 && to >= 5) {
        await _migrateV4ToV5HomeAssistant(this, m);
        if (to == 5) {
          return;
        }
        from = 5;
      }
      if (from == 5 && to >= 6) {
        await _migrateV5ToV6IntegrationTypesAndDefaults(this);
        return;
      }
      throw UnsupportedError(
        'Unsupported database upgrade from version $from to $to. '
        'Delete the SQLite file and reinstall (fresh seed).',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// Integration ids that require operator-configured secrets (schema 2 → 3 cutover).
const kIntegrationsDisabledOnSecretStoreMigration = <String>[
  'joke_openai',
  'trivia_openai',
  'weather_openweathermap',
  'media_pexels',
  'media_flickr',
  'stock_finnhub',
  'calendar_google',
  'calendar_outlook',
  'media_onedrive',
];

/// Default integration row ids after schema 6 (seed + migration).
const String kDefaultNewsRssIntegrationId = 'default_news_rss';
const String kDefaultJokeOpenAiIntegrationId = 'default_joke_openai';
const String kDefaultTriviaOpenAiIntegrationId = 'default_trivia_openai';
const String kDefaultTriviaOpenTdbIntegrationId = 'default_trivia_opentdb';
const String kDefaultWeatherOpenWeatherMapIntegrationId =
    'default_weather_openweathermap';
const String kDefaultWeatherAlertsNwsIntegrationId =
    'default_weather_alerts_nws';
const String kDefaultPhotoPexelsIntegrationId = 'default_photo_pexels';
const String kDefaultVideoPexelsIntegrationId = 'default_video_pexels';
const String kDefaultStockFinnhubIntegrationId = 'default_stock_finnhub';
const String kDefaultHomeAssistantIntegrationId = 'default_home_assistant';
const String kDefaultCalendarGoogleIntegrationId = 'default_calendar_google';
const String kDefaultCalendarOutlookIntegrationId = 'default_calendar_outlook';
const String kDefaultPhotoOneDriveIntegrationId = 'default_photo_onedrive';
const String kDefaultVideoOneDriveIntegrationId = 'default_video_onedrive';
const String kDefaultPhotoFlickrIntegrationId = 'default_photo_flickr';
const String kDefaultPhotoBingIotdIntegrationId =
    'default_photo_bing_image_of_the_day';

/// Adds encrypted secret tables and disables env-dependent integrations.
Future<void> _migrateV2ToV3IntegrationSecrets(
  AppDatabase db,
  Migrator m,
) async {
  await m.createTable(db.integrationSecrets);
  await m.createTable(db.secretStoreMeta);
  final integrationsPresent = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='integrations' LIMIT 1",
      )
      .get();
  if (integrationsPresent.isEmpty) {
    return;
  }
  for (final id in kIntegrationsDisabledOnSecretStoreMigration) {
    await db.customStatement(
      'UPDATE integrations SET enabled = 0 WHERE id = ?',
      [id],
    );
  }
}

/// Adds plugin install registry and runtime signal KV store (schema 3 → 4).
Future<void> _migrateV3ToV4PluginRuntime(AppDatabase db, Migrator m) async {
  await m.createTable(db.installedPlugins);
  await m.createTable(db.runtimeSignals);
}

/// Adds Home Assistant entity interests and state cache (schema 4 → 5).
Future<void> _migrateV4ToV5HomeAssistant(AppDatabase db, Migrator m) async {
  await m.createTable(db.interestsHomeAssistantEntities);
  await m.createTable(db.homeAssistantEntityStates);
}

/// Renames legacy interest catalog tables to `interests_*` (schema 1 → 2).
Future<void> _migrateV1ToV2InterestsTableRenames(AppDatabase db) async {
  await db.customStatement(
    'ALTER TABLE weather_locations RENAME TO interests_locations',
  );
  await db.customStatement(
    'ALTER TABLE rss_feed_sources RENAME TO interests_rss_feeds',
  );
  await db.customStatement(
    'ALTER TABLE joke_categories RENAME TO interests_jokes',
  );
  await db.customStatement(
    'ALTER TABLE trivia_categories RENAME TO interests_trivia',
  );
  await db.customStatement(
    'ALTER TABLE stock_symbols RENAME TO interests_stock_symbols',
  );
}

Future<void> _seedDefaultRejectTerms(AppDatabase db) async {
  final existing = await db.select(db.rejectTerms).get();
  if (existing.isNotEmpty) {
    return;
  }
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  for (final entry in kDefaultRejectTermSeeds) {
    await db
        .into(db.rejectTerms)
        .insert(
          RejectTermsCompanion.insert(
            id: entry.id,
            term: entry.term,
            action: entry.action,
            createdAtMs: nowMs,
            updatedAtMs: nowMs,
          ),
        );
  }
}

/// Opens a file-backed SQLite at [sqliteFile] (e.g. for `waddlectl --database`).
QueryExecutor createQueryExecutorForFile(File sqliteFile) {
  return LazyDatabase(() async {
    log('SQLite database file: ${sqliteFile.path}', name: 'waddle_shared');
    return NativeDatabase.createInBackground(sqliteFile);
  });
}
