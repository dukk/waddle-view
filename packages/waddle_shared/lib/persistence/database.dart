import 'dart:developer' show log;
import 'dart:io';
import 'dart:typed_data';

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

/// Renames `provider_type` → `integration_type`, splits media integrations, and
/// moves legacy row ids to `default_*` slugs.
Future<void> _migrateV5ToV6IntegrationTypesAndDefaults(AppDatabase db) async {
  final integrationsPresent = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='integrations' LIMIT 1",
      )
      .get();
  if (integrationsPresent.isEmpty) {
    return;
  }

  final columns = await db.customSelect('PRAGMA table_info(integrations)').get();
  final hasProviderType = columns.any((c) => c.read<String>('name') == 'provider_type');
  final hasIntegrationType =
      columns.any((c) => c.read<String>('name') == 'integration_type');
  if (hasProviderType && !hasIntegrationType) {
    await db.customStatement(
      'ALTER TABLE integrations RENAME COLUMN provider_type TO integration_type',
    );
  }

  const typeRenames = <String, String>{
    'media_flickr': 'photo_flickr',
    'media_bing_iotd': 'photo_bing_image_of_the_day',
    'weather_nws_alerts': 'weather_alerts_nws',
  };
  for (final e in typeRenames.entries) {
    await db.customStatement(
      'UPDATE integrations SET integration_type = ? WHERE integration_type = ?',
      [e.value, e.key],
    );
  }

  Future<void> updateDataProviderIfTable(String table, String set, String where) async {
    final present = await db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
          variables: [Variable<String>(table)],
        )
        .get();
    if (present.isEmpty) {
      return;
    }
    await db.customStatement(
      'UPDATE $table SET data_provider = ? WHERE data_provider = ?',
      [set, where],
    );
  }

  await updateDataProviderIfTable('photos', 'photo_pexels', 'media_pexels');
  await updateDataProviderIfTable('videos', 'video_pexels', 'media_pexels');
  await updateDataProviderIfTable('photos', 'photo_onedrive', 'media_onedrive');
  await updateDataProviderIfTable('videos', 'video_onedrive', 'media_onedrive');
  await updateDataProviderIfTable('photos', 'photo_flickr', 'media_flickr');
  await updateDataProviderIfTable(
    'photos',
    'photo_bing_image_of_the_day',
    'media_bing_iotd',
  );

  final pexelsRow = await db.customSelect(
    'SELECT * FROM integrations WHERE id = ? OR integration_type = ? LIMIT 1',
    variables: [
      const Variable<String>('media_pexels'),
      const Variable<String>('media_pexels'),
    ],
  ).getSingleOrNull();
  if (pexelsRow != null) {
    final oldId = pexelsRow.read<String>('id');
    final configJson = pexelsRow.read<String?>('config_json');
    final schema = pexelsRow.read<String?>('config_json_schema');
    final example = pexelsRow.read<String?>('example_config_json');
    final enabled = pexelsRow.read<int>('enabled');
    final poll = pexelsRow.read<int>('poll_seconds');
    final baseUrl = pexelsRow.read<String?>('base_url');

    await db.customStatement(
      'UPDATE integrations SET id = ?, integration_type = ? WHERE id = ?',
      [kDefaultPhotoPexelsIntegrationId, 'photo_pexels', oldId],
    );
    await _migrateIntegrationSecretKeys(db, oldId, kDefaultPhotoPexelsIntegrationId);
    await _migrateConfigKvPrefix(db, oldId, kDefaultPhotoPexelsIntegrationId);

    final videoExists = await db.customSelect(
      'SELECT 1 FROM integrations WHERE id = ? LIMIT 1',
      variables: [Variable<String>(kDefaultVideoPexelsIntegrationId)],
    ).getSingleOrNull();
    if (videoExists == null) {
      await db.customStatement(
        'INSERT INTO integrations '
        '(id, integration_type, enabled, poll_seconds, base_url, config_json, '
        'config_json_schema, example_config_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          kDefaultVideoPexelsIntegrationId,
          'video_pexels',
          enabled,
          poll,
          baseUrl,
          configJson,
          schema,
          example,
        ],
      );
      await _copyAccessTokenSecret(
        db,
        kDefaultPhotoPexelsIntegrationId,
        kDefaultVideoPexelsIntegrationId,
      );
    }
  }

  final onedriveRow = await db.customSelect(
    'SELECT * FROM integrations WHERE id = ? OR integration_type = ? LIMIT 1',
    variables: [
      const Variable<String>('media_onedrive'),
      const Variable<String>('media_onedrive'),
    ],
  ).getSingleOrNull();
  if (onedriveRow != null) {
    final oldId = onedriveRow.read<String>('id');
    final configJson = onedriveRow.read<String?>('config_json');
    final schema = onedriveRow.read<String?>('config_json_schema');
    final example = onedriveRow.read<String?>('example_config_json');
    final enabled = onedriveRow.read<int>('enabled');
    final poll = onedriveRow.read<int>('poll_seconds');
    final baseUrl = onedriveRow.read<String?>('base_url');

    await db.customStatement(
      'UPDATE integrations SET id = ?, integration_type = ? WHERE id = ?',
      [kDefaultPhotoOneDriveIntegrationId, 'photo_onedrive', oldId],
    );
    await _migrateIntegrationSecretKeys(db, oldId, kDefaultPhotoOneDriveIntegrationId);
    await _migrateConfigKvPrefix(db, oldId, kDefaultPhotoOneDriveIntegrationId);

    final videoExists = await db.customSelect(
      'SELECT 1 FROM integrations WHERE id = ? LIMIT 1',
      variables: [Variable<String>(kDefaultVideoOneDriveIntegrationId)],
    ).getSingleOrNull();
    if (videoExists == null) {
      await db.customStatement(
        'INSERT INTO integrations '
        '(id, integration_type, enabled, poll_seconds, base_url, config_json, '
        'config_json_schema, example_config_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          kDefaultVideoOneDriveIntegrationId,
          'video_onedrive',
          enabled,
          poll,
          baseUrl,
          configJson,
          schema,
          example,
        ],
      );
    }
  }

  const idMigrations = <String, String>{
    'news_rss': kDefaultNewsRssIntegrationId,
    'joke_openai': kDefaultJokeOpenAiIntegrationId,
    'trivia_openai': kDefaultTriviaOpenAiIntegrationId,
    'trivia_opentdb': kDefaultTriviaOpenTdbIntegrationId,
    'weather_openweathermap': kDefaultWeatherOpenWeatherMapIntegrationId,
    'weather_nws_alerts': kDefaultWeatherAlertsNwsIntegrationId,
    'weather_alerts_nws': kDefaultWeatherAlertsNwsIntegrationId,
    'stock_finnhub': kDefaultStockFinnhubIntegrationId,
    'home_assistant': kDefaultHomeAssistantIntegrationId,
    'calendar_google': kDefaultCalendarGoogleIntegrationId,
    'calendar_outlook': kDefaultCalendarOutlookIntegrationId,
    'media_flickr': kDefaultPhotoFlickrIntegrationId,
    'photo_flickr': kDefaultPhotoFlickrIntegrationId,
    'media_bing_iotd': kDefaultPhotoBingIotdIntegrationId,
    'photo_bing_image_of_the_day': kDefaultPhotoBingIotdIntegrationId,
  };
  for (final e in idMigrations.entries) {
    final exists = await db.customSelect(
      'SELECT 1 FROM integrations WHERE id = ? LIMIT 1',
      variables: [Variable<String>(e.key)],
    ).getSingleOrNull();
    if (exists == null) {
      continue;
    }
    final targetTaken = await db.customSelect(
      'SELECT 1 FROM integrations WHERE id = ? LIMIT 1',
      variables: [Variable<String>(e.value)],
    ).getSingleOrNull();
    if (targetTaken != null) {
      continue;
    }
    await db.customStatement(
      'UPDATE integrations SET id = ? WHERE id = ?',
      [e.value, e.key],
    );
    await _migrateIntegrationSecretKeys(db, e.key, e.value);
    await _migrateConfigKvPrefix(db, e.key, e.value);
  }
}

Future<void> _migrateIntegrationSecretKeys(
  AppDatabase db,
  String oldIntegrationId,
  String newIntegrationId,
) async {
  final secretsPresent = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='integration_secrets' LIMIT 1",
      )
      .get();
  if (secretsPresent.isEmpty) {
    return;
  }
  final oldPrefix = 'provider:access_token:$oldIntegrationId';
  final newPrefix = 'provider:access_token:$newIntegrationId';
  await db.customStatement(
    'UPDATE integration_secrets SET key = REPLACE(key, ?, ?) WHERE key = ? OR key LIKE ?',
    [oldPrefix, newPrefix, oldPrefix, '$oldPrefix:%'],
  );
}

Future<void> _migrateConfigKvPrefix(
  AppDatabase db,
  String oldIntegrationId,
  String newIntegrationId,
) async {
  final kvPresent = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='config_key_values' LIMIT 1",
      )
      .get();
  if (kvPresent.isEmpty) {
    return;
  }
  final oldKey = 'provider.$oldIntegrationId.last_collect_ms';
  final newKey = 'provider.$newIntegrationId.last_collect_ms';
  await db.customStatement(
    'UPDATE config_key_values SET key = ? WHERE key = ?',
    [newKey, oldKey],
  );
}

Future<void> _copyAccessTokenSecret(
  AppDatabase db,
  String fromIntegrationId,
  String toIntegrationId,
) async {
  final secretsPresent = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='integration_secrets' LIMIT 1",
      )
      .get();
  if (secretsPresent.isEmpty) {
    return;
  }
  final fromKey = 'provider:access_token:$fromIntegrationId';
  final toKey = 'provider:access_token:$toIntegrationId';
  final row = await db.customSelect(
    'SELECT ciphertext, nonce, updated_at_ms FROM integration_secrets WHERE key = ?',
    variables: [Variable<String>(fromKey)],
  ).getSingleOrNull();
  if (row == null) {
    return;
  }
  await db.customStatement(
    'INSERT OR REPLACE INTO integration_secrets (key, ciphertext, nonce, updated_at_ms) '
    'VALUES (?, ?, ?, ?)',
    [
      toKey,
      row.read<Uint8List>('ciphertext'),
      row.read<Uint8List>('nonce'),
      row.read<int>('updated_at_ms'),
    ],
  );
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
