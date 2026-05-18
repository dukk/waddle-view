import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../config/integration_config_json.dart';
import '../integration_accounts/integration_accounts_service.dart';
import '../seed/tables/interests_locations_seed.dart';
import 'display_overlay_sql.dart';
import 'reject_term_defaults.dart';
import 'tables.dart';
import 'weather_location_category.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    ContentCategories,
    Integrations,
    IntegrationAccounts,
    IntegrationAccountLinks,
    IntegrationsKeyValue,
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
    News,
    InterestsFacebookSources,
    InterestsTwitterSources,
    InterestsLinkedinSources,
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
  int get schemaVersion => 21;

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
      await _ensureIntegrationsKeyValueIndexes(this);
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
        if (to == 6) {
          return;
        }
        from = 6;
      }
      if (from == 6 && to >= 7) {
        await _migrateV6ToV7IntegrationAccounts(this, m);
        if (to == 7) {
          return;
        }
        from = 7;
      }
      if (from == 7 && to >= 8) {
        await _migrateV7ToV8WeatherLocationCategories(this);
        if (to == 8) {
          return;
        }
        from = 8;
      }
      if (from == 8 && to >= 9) {
        await _migrateV8ToV9LocationInterestFlags(this);
        if (to == 9) {
          return;
        }
        from = 9;
      }
      if (from == 9 && to >= 10) {
        await _migrateV9ToV10IntegrationAccountLinks(this, m);
        if (to == 10) {
          return;
        }
        from = 10;
      }
      if (from == 10 && to >= 11) {
        await _migrateV10ToV11LocationRegions(this);
        if (to == 11) {
          return;
        }
        from = 11;
      }
      if (from == 11 && to >= 12) {
        await _migrateV11ToV12CuratorTickerEnabled(this);
        if (to == 12) {
          return;
        }
        from = 12;
      }
      if (from == 12 && to >= 13) {
        await _migrateV12ToV13NewsAndFacebookSources(this, m);
        if (to == 13) {
          return;
        }
        from = 13;
      }
      if (from == 13 && to >= 14) {
        await _migrateV13ToV14SocialNewsSources(this, m);
        if (to == 14) {
          return;
        }
        from = 14;
      }
      if (from == 14 && to >= 15) {
        await _ensureCuratorConfigurationsTickerEnabled(this);
        if (to == 15) {
          return;
        }
        from = 15;
      }
      if (from == 15 && to >= 16) {
        await _migrateV15ToV16IntegrationsConfigColumns(this);
        if (to == 16) {
          return;
        }
        from = 16;
      }
      if (from == 16 && to >= 17) {
        await _migrateV16ToV17CuratorTickerProgramDuration(this);
        if (to == 17) {
          return;
        }
        from = 17;
      }
      if (from == 17 && to >= 18) {
        await _migrateV17ToV18OverlaysDefinitionOnly(this);
        if (to == 18) {
          return;
        }
        from = 18;
      }
      if (from == 18 && to >= 19) {
        await _migrateV18ToV19CuratorTickerPixelsPerSecond(this);
        if (to == 19) {
          return;
        }
        from = 19;
      }
      if (from == 19 && to >= 20) {
        await _migrateV19ToV20OverlaysShapeRainAndDropExample(this);
        if (to == 20) {
          return;
        }
        from = 20;
      }
      if (from == 20 && to >= 21) {
        await _migrateV20ToV21IntegrationsKeyValue(this, m);
        return;
      }
      throw UnsupportedError(
        'Unsupported database upgrade from version $from to $to. '
        'Delete the SQLite file and reinstall (fresh seed).',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _ensureCuratorConfigurationsTickerEnabled(this);
      await _ensureCuratorConfigurationsTickerProgramDuration(this);
      await _ensureCuratorConfigurationsTickerPixelsPerSecond(this);
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
const String kDefaultNewsFacebookIntegrationId = 'default_news_facebook';
const String kDefaultNewsTwitterIntegrationId = 'default_news_twitter';
const String kDefaultNewsLinkedinIntegrationId = 'default_news_linkedin';
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
const String kDefaultCalendarIcalIntegrationId = 'default_calendar_ical';
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
    'calendar_ical': kDefaultCalendarIcalIntegrationId,
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

Future<String?> _integrationSecretsStorageKeyColumn(AppDatabase db) async {
  final columns =
      await db.customSelect('PRAGMA table_info(integration_secrets)').get();
  if (columns.any((c) => c.read<String>('name') == 'secret_key')) {
    return 'secret_key';
  }
  if (columns.any((c) => c.read<String>('name') == 'key')) {
    return 'key';
  }
  return null;
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
  final keyColumn = await _integrationSecretsStorageKeyColumn(db);
  if (keyColumn == null) {
    return;
  }
  final oldPrefix = 'provider:access_token:$oldIntegrationId';
  final newPrefix = 'provider:access_token:$newIntegrationId';
  await db.customStatement(
    'UPDATE integration_secrets SET $keyColumn = REPLACE($keyColumn, ?, ?) '
    'WHERE $keyColumn = ? OR $keyColumn LIKE ?',
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
  final keyColumn = await _integrationSecretsStorageKeyColumn(db);
  if (keyColumn == null) {
    return;
  }
  final fromKey = 'provider:access_token:$fromIntegrationId';
  final toKey = 'provider:access_token:$toIntegrationId';
  final columns =
      await db.customSelect('PRAGMA table_info(integration_secrets)').get();
  final hasNonce = columns.any((c) => c.read<String>('name') == 'nonce');
  if (hasNonce) {
    final row = await db.customSelect(
      'SELECT ciphertext, nonce, updated_at_ms FROM integration_secrets '
      'WHERE $keyColumn = ?',
      variables: [Variable<String>(fromKey)],
    ).getSingleOrNull();
    if (row == null) {
      return;
    }
    await db.customStatement(
      'INSERT OR REPLACE INTO integration_secrets '
      '($keyColumn, ciphertext, nonce, updated_at_ms) VALUES (?, ?, ?, ?)',
      [
        toKey,
        row.read<Uint8List>('ciphertext'),
        row.read<Uint8List>('nonce'),
        row.read<int>('updated_at_ms'),
      ],
    );
    return;
  }
  final row = await db.customSelect(
    'SELECT ciphertext, updated_at_ms FROM integration_secrets WHERE $keyColumn = ?',
    variables: [Variable<String>(fromKey)],
  ).getSingleOrNull();
  if (row == null) {
    return;
  }
  await db.customStatement(
    'INSERT OR REPLACE INTO integration_secrets '
    '($keyColumn, ciphertext, updated_at_ms) VALUES (?, ?, ?)',
    [
      toKey,
      row.read<Uint8List>('ciphertext'),
      row.read<int>('updated_at_ms'),
    ],
  );
}

Future<bool> _sqliteTableExists(AppDatabase db, String tableName) async {
  final row = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
    variables: [Variable<String>(tableName)],
  ).getSingleOrNull();
  return row != null;
}

Future<bool> _sqliteColumnExists(
  AppDatabase db,
  String tableName,
  String columnName,
) async {
  final rows = await db.customSelect('PRAGMA table_info($tableName)').get();
  return rows.any((r) => r.read<String>('name') == columnName);
}

/// Renames legacy interest catalog tables to `interests_*` (schema 1 → 2).
Future<void> _migrateV1ToV2InterestsTableRenames(AppDatabase db) async {
  if (await _sqliteTableExists(db, 'weather_locations')) {
    await db.customStatement(
      'ALTER TABLE weather_locations RENAME TO interests_locations',
    );
  }
  if (await _sqliteTableExists(db, 'rss_feed_sources')) {
    await db.customStatement(
      'ALTER TABLE rss_feed_sources RENAME TO interests_rss_feeds',
    );
  }
  if (await _sqliteTableExists(db, 'joke_categories')) {
    await db.customStatement(
      'ALTER TABLE joke_categories RENAME TO interests_jokes',
    );
  }
  if (await _sqliteTableExists(db, 'trivia_categories')) {
    await db.customStatement(
      'ALTER TABLE trivia_categories RENAME TO interests_trivia',
    );
  }
  if (await _sqliteTableExists(db, 'stock_symbols')) {
    await db.customStatement(
      'ALTER TABLE stock_symbols RENAME TO interests_stock_symbols',
    );
  }
}

Future<void> _migrateV6ToV7IntegrationAccounts(
  AppDatabase db,
  Migrator m,
) async {
  await m.createTable(db.integrationAccounts);
  if (!await _sqliteTableExists(db, 'integrations')) {
    return;
  }
  await syncIntegrationAccountsFromIntegrationConfigs(db);
}

Future<void> _migrateV9ToV10IntegrationAccountLinks(
  AppDatabase db,
  Migrator m,
) async {
  await m.createTable(db.integrationAccountLinks);
  if (!await _sqliteTableExists(db, 'integrations')) {
    return;
  }
  await syncIntegrationAccountsFromIntegrationConfigs(db);
  await syncIntegrationAccountLinks(db);
}

Future<void> _migrateV7ToV8WeatherLocationCategories(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'interests_locations')) {
    return;
  }
  if (await _sqliteColumnExists(db, 'interests_locations', 'category')) {
    return;
  }
  await db.customStatement(
    "ALTER TABLE interests_locations ADD COLUMN category TEXT NOT NULL DEFAULT 'general'",
  );
  final rows = await db.customSelect(
    'SELECT id, name FROM interests_locations',
  ).get();
  for (final row in rows) {
    final category = weatherLocationCategoryFromName(row.read<String>('name'));
    await db.customStatement(
      'UPDATE interests_locations SET category = ? WHERE id = ?',
      [category, row.read<String>('id')],
    );
  }
}

/// Renames location interest flags and adds [InterestsLocations.includeLocalNews].
Future<void> _migrateV8ToV9LocationInterestFlags(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'interests_locations')) {
    return;
  }
  if (await _sqliteColumnExists(db, 'interests_locations', 'enabled')) {
    await db.customStatement(
      'ALTER TABLE interests_locations RENAME COLUMN enabled TO include_weather',
    );
  }
  if (await _sqliteColumnExists(
    db,
    'interests_locations',
    'include_active_weather_alerts',
  )) {
    await db.customStatement(
      'ALTER TABLE interests_locations RENAME COLUMN '
      'include_active_weather_alerts TO include_weather_alerts',
    );
  }
  if (!await _sqliteColumnExists(db, 'interests_locations', 'include_local_news')) {
    await db.customStatement(
      'ALTER TABLE interests_locations ADD COLUMN include_local_news '
      'INTEGER NOT NULL DEFAULT 0',
    );
  }
  await ensureDefaultInterestsLocations(db);
}

/// Refreshes default location catalog rows (continental categories and new cities).
Future<void> _migrateV10ToV11LocationRegions(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'interests_locations')) {
    return;
  }
  await ensureDefaultInterestsLocations(db);
}

/// Renames `rss_articles` → `news` and adds Facebook interest sources (12 → 13).
Future<void> _migrateV12ToV13NewsAndFacebookSources(
  AppDatabase db,
  Migrator m,
) async {
  final rssTable = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='rss_articles' LIMIT 1",
      )
      .getSingleOrNull();
  if (rssTable != null) {
    await db.customStatement('ALTER TABLE rss_articles RENAME TO news');
    await db.customStatement(
      "ALTER TABLE news ADD COLUMN source_type TEXT NOT NULL DEFAULT '$kNewsSourceTypeRss'",
    );
    await db.customStatement(
      'ALTER TABLE news RENAME COLUMN feed_id TO source_id',
    );
  }
  final fbTable = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type='table' "
        "AND name='interests_facebook_sources' LIMIT 1",
      )
      .getSingleOrNull();
  if (fbTable == null) {
    await m.createTable(db.interestsFacebookSources);
  }
}

/// Adds Twitter and LinkedIn interest source tables (13 → 14).
Future<void> _migrateV13ToV14SocialNewsSources(
  AppDatabase db,
  Migrator m,
) async {
  await m.createTable(db.interestsTwitterSources);
  await m.createTable(db.interestsLinkedinSources);
}

Future<void> _migrateV11ToV12CuratorTickerEnabled(AppDatabase db) async {
  await _ensureCuratorConfigurationsTickerEnabled(db);
}

/// Ensures [CuratorConfigurations.tickerEnabled] is present and non-null.
///
/// Databases that reached schema 14 before this column existed in [onCreate]
/// can have NULL values and crash Drift reads during seed/bootstrap.
Future<void> _ensureCuratorConfigurationsTickerEnabled(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'curator_configurations')) {
    return;
  }
  if (!await _sqliteColumnExists(db, 'curator_configurations', 'ticker_enabled')) {
    await db.customStatement(
      'ALTER TABLE curator_configurations ADD COLUMN ticker_enabled '
      'INTEGER NOT NULL DEFAULT 1',
    );
  }
  await db.customStatement(
    'UPDATE curator_configurations SET ticker_enabled = 1 '
    'WHERE ticker_enabled IS NULL',
  );
}

Future<void> _migrateV16ToV17CuratorTickerProgramDuration(AppDatabase db) async {
  await _ensureCuratorConfigurationsTickerProgramDuration(db);
}

/// Drops per-row overlay calendar columns; renames `label` → `name`.
Future<void> _migrateV17ToV18OverlaysDefinitionOnly(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'overlays')) {
    return;
  }
  if (await _sqliteColumnExists(db, 'overlays', 'name')) {
    return;
  }
  if (!await _sqliteColumnExists(db, 'overlays', 'label')) {
    return;
  }
  await db.customStatement(kCreateOverlaysNewTableSql);
  await db.customStatement(kCopyOverlaysToNewFromLegacySql);
  await db.customStatement('DROP TABLE overlays');
  await db.customStatement('ALTER TABLE overlays_new RENAME TO overlays');
}

/// Renames default overlay seeds, migrates `hearts_rain` → `shape_rain`, drops
/// per-row `example_config_json`.
Future<void> _migrateV19ToV20OverlaysShapeRainAndDropExample(
  AppDatabase db,
) async {
  if (!await _sqliteTableExists(db, 'overlays')) {
    await db.customStatement(kEnsureOverlaysTableSql);
    return;
  }

  await db.customStatement(
    "UPDATE overlays SET overlay_type = 'shape_rain' "
    "WHERE overlay_type = 'hearts_rain'",
  );
  await db.customStatement(
    'UPDATE overlays SET overlay_type = ?, name = ?, config_json = ? '
    'WHERE id = ?',
    <Object?>[
      kOverlayTypeShapeRain,
      'Raining Hearts',
      jsonEncode(<String, Object?>{
        'shapes': <String>['heart', 'raindrop', 'cat', 'dog'],
      }),
      kDefaultMothersDayOverlayId,
    ],
  );
  await db.customStatement(
    'UPDATE curator_configuration_members SET entity_id = ? '
    "WHERE entity_type = ? AND entity_id = 'default_birthday_example_may_13'",
    <Object?>[
      kDefaultBirthdayConfettiOverlayId,
      kCuratorMemberEntityOverlay,
    ],
  );
  await db.customStatement(
    'UPDATE overlays SET id = ?, name = ? WHERE id = ?',
    <Object?>[
      kDefaultBirthdayConfettiOverlayId,
      'Default Birthday Confetti',
      'default_birthday_example_may_13',
    ],
  );
  await db.customStatement(
    'UPDATE curator_configuration_members SET entity_id = ? '
    "WHERE entity_type = ? AND entity_id = 'default_bouncing_message_may_13'",
    <Object?>[
      kDefaultWattleViewsBirthdayMessageOverlayId,
      kCuratorMemberEntityOverlay,
    ],
  );
  await db.customStatement(
    'UPDATE overlays SET id = ?, name = ? WHERE id = ?',
    <Object?>[
      kDefaultWattleViewsBirthdayMessageOverlayId,
      "Wattle View's Birthday Message!",
      'default_bouncing_message_may_13',
    ],
  );

  if (await _sqliteColumnExists(db, 'overlays', 'example_config_json')) {
    await db.customStatement(kCreateOverlaysWithoutExampleTableSql);
    await db.customStatement(kCopyOverlaysWithoutExampleSql);
    await db.customStatement('DROP TABLE overlays');
    await db.customStatement('ALTER TABLE overlays_new RENAME TO overlays');
  }
}

/// Ensures [CuratorConfigurations.tickerProgramDurationSeconds] is present.
Future<void> _ensureCuratorConfigurationsTickerProgramDuration(
  AppDatabase db,
) async {
  if (!await _sqliteTableExists(db, 'curator_configurations')) {
    return;
  }
  if (!await _sqliteColumnExists(
    db,
    'curator_configurations',
    'ticker_program_duration_seconds',
  )) {
    await db.customStatement(
      'ALTER TABLE curator_configurations ADD COLUMN '
      'ticker_program_duration_seconds INTEGER NOT NULL DEFAULT 300',
    );
  }
}

const _kCuratorTickerPixelsPerSecondMin = 20;
const _kCuratorTickerPixelsPerSecondMax = 140;
const _kCuratorTickerPixelsPerSecondDefault = 80;

int _clampCuratorTickerPixelsPerSecond(int value) {
  if (value < _kCuratorTickerPixelsPerSecondMin) {
    return _kCuratorTickerPixelsPerSecondMin;
  }
  if (value > _kCuratorTickerPixelsPerSecondMax) {
    return _kCuratorTickerPixelsPerSecondMax;
  }
  return value;
}

/// Ensures [CuratorConfigurations.tickerPixelsPerSecond] is present.
Future<void> _ensureCuratorConfigurationsTickerPixelsPerSecond(
  AppDatabase db,
) async {
  if (!await _sqliteTableExists(db, 'curator_configurations')) {
    return;
  }
  if (!await _sqliteColumnExists(
    db,
    'curator_configurations',
    'ticker_pixels_per_second',
  )) {
    await db.customStatement(
      'ALTER TABLE curator_configurations ADD COLUMN '
      'ticker_pixels_per_second INTEGER NOT NULL DEFAULT $_kCuratorTickerPixelsPerSecondDefault',
    );
  }
}

Future<void> _migrateV18ToV19CuratorTickerPixelsPerSecond(AppDatabase db) async {
  await _ensureCuratorConfigurationsTickerPixelsPerSecond(db);
  var migratedPx = _kCuratorTickerPixelsPerSecondDefault;
  if (await _sqliteTableExists(db, 'config_key_values')) {
    final kvRow = await db.customSelect(
      "SELECT value FROM config_key_values WHERE key = 'curator.ticker.newsPixelsPerSecond' LIMIT 1",
    ).getSingleOrNull();
    final raw = kvRow?.read<String?>('value')?.trim();
    if (raw != null && raw.isNotEmpty) {
      migratedPx = _clampCuratorTickerPixelsPerSecond(int.tryParse(raw) ?? migratedPx);
    }
  }
  await db.customStatement(
    'UPDATE curator_configurations SET ticker_pixels_per_second = ?',
    <Object?>[migratedPx],
  );
}

/// Moves `base_url` into `config_json.baseUrl` and drops `example_config_json`.
Future<void> _migrateV15ToV16IntegrationsConfigColumns(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'integrations')) {
    return;
  }
  final hasBaseUrl =
      await _sqliteColumnExists(db, 'integrations', 'base_url');
  final hasExample =
      await _sqliteColumnExists(db, 'integrations', 'example_config_json');
  if (!hasBaseUrl && !hasExample) {
    return;
  }

  final rows = await db.customSelect('SELECT * FROM integrations').get();
  await db.customStatement('PRAGMA foreign_keys = OFF');
  await db.customStatement('''
CREATE TABLE integrations_new (
  id TEXT NOT NULL PRIMARY KEY,
  integration_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  config_json TEXT,
  config_json_schema TEXT
)
''');
  for (final row in rows) {
    final configJson = mergeBaseUrlIntoIntegrationConfig(
      row.read<String?>('config_json'),
      row.read<String?>('base_url'),
    );
    await db.customStatement(
      'INSERT INTO integrations_new '
      '(id, integration_type, enabled, poll_seconds, config_json, config_json_schema) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        row.read<String>('id'),
        row.read<String>('integration_type'),
        row.read<int>('enabled'),
        row.read<int>('poll_seconds'),
        configJson,
        row.read<String?>('config_json_schema'),
      ],
    );
  }
  await db.customStatement('DROP TABLE integrations');
  await db.customStatement('ALTER TABLE integrations_new RENAME TO integrations');
  await db.customStatement('PRAGMA foreign_keys = ON');
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

Future<void> _ensureIntegrationsKeyValueIndexes(AppDatabase db) async {
  await db.customStatement('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_integrations_kv_integration_key
ON integrations_key_value (integration_id, key)
WHERE integration_id IS NOT NULL
''');
  await db.customStatement('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_integrations_kv_account_key
ON integrations_key_value (account_id, key)
WHERE account_id IS NOT NULL
''');
}

class _LegacyIntegrationKvMapping {
  const _LegacyIntegrationKvMapping({
    this.integrationId,
    this.accountId,
    required this.key,
    required this.valueType,
  });

  final String? integrationId;
  final String? accountId;
  final String key;
  final String valueType;
}

Future<String?> _resolveOnedriveIntegrationIdForAccount(
  AppDatabase db,
  String accountKey,
) async {
  final links = await db.customSelect(
    '''
SELECT l.integration_id AS integration_id
FROM integration_account_links l
INNER JOIN integrations i ON i.id = l.integration_id
WHERE l.account_id = ?
  AND i.integration_type IN ('photo_onedrive', 'video_onedrive')
''',
    variables: [Variable<String>(accountKey)],
  ).get();
  if (links.isEmpty) {
    return null;
  }
  final ids = links.map((r) => r.read<String>('integration_id')).toList();
  if (ids.contains(kDefaultPhotoOneDriveIntegrationId)) {
    return kDefaultPhotoOneDriveIntegrationId;
  }
  if (ids.contains(kDefaultVideoOneDriveIntegrationId)) {
    return kDefaultVideoOneDriveIntegrationId;
  }
  return ids.first;
}

Future<_LegacyIntegrationKvMapping?> _mapLegacyIntegrationKvKey(
  AppDatabase db,
  String legacyKey,
) async {
  const lastCollectSuffix = '.last_collect_ms';
  if (legacyKey.startsWith('provider.') &&
      legacyKey.endsWith(lastCollectSuffix)) {
    final mid = legacyKey.substring(
      'provider.'.length,
      legacyKey.length - lastCollectSuffix.length,
    );
    final integrationId = switch (mid) {
      'calendar_google' => kDefaultCalendarGoogleIntegrationId,
      'calendar_outlook' => kDefaultCalendarOutlookIntegrationId,
      'calendar_ical' => kDefaultCalendarIcalIntegrationId,
      _ => mid,
    };
    return _LegacyIntegrationKvMapping(
      integrationId: integrationId,
      key: 'last_collect_ms',
      valueType: 'int_ms',
    );
  }

  const googleExpiresPrefix = 'google.access_token_expires_at_ms.';
  if (legacyKey.startsWith(googleExpiresPrefix)) {
    return _LegacyIntegrationKvMapping(
      accountId: legacyKey.substring(googleExpiresPrefix.length),
      key: 'access_token_expires_at_ms',
      valueType: 'int_ms',
    );
  }

  const googlePromptPrefix = 'provider.calendar_google.last_device_prompt_ms.';
  if (legacyKey.startsWith(googlePromptPrefix)) {
    return _LegacyIntegrationKvMapping(
      accountId: legacyKey.substring(googlePromptPrefix.length),
      key: 'last_device_prompt_ms',
      valueType: 'int_ms',
    );
  }

  const graphExpiresPrefix = 'microsoft.graph.access_token_expires_at_ms.';
  if (legacyKey.startsWith(graphExpiresPrefix)) {
    return _LegacyIntegrationKvMapping(
      accountId: legacyKey.substring(graphExpiresPrefix.length),
      key: 'access_token_expires_at_ms',
      valueType: 'int_ms',
    );
  }

  const outlookPromptPrefix = 'provider.calendar_outlook.last_device_prompt_ms.';
  if (legacyKey.startsWith(outlookPromptPrefix)) {
    return _LegacyIntegrationKvMapping(
      accountId: legacyKey.substring(outlookPromptPrefix.length),
      key: 'last_device_prompt_ms',
      valueType: 'int_ms',
    );
  }

  const deltaPrefix = 'provider.media_onedrive.delta_link.';
  if (legacyKey.startsWith(deltaPrefix)) {
    final rest = legacyKey.substring(deltaPrefix.length);
    final dot = rest.indexOf('.');
    if (dot <= 0) {
      return null;
    }
    final accountKey = rest.substring(0, dot);
    final pathTag = rest.substring(dot + 1);
    final integrationId =
        await _resolveOnedriveIntegrationIdForAccount(db, accountKey);
    if (integrationId == null) {
      return null;
    }
    return _LegacyIntegrationKvMapping(
      integrationId: integrationId,
      key: 'delta_link.$pathTag',
      valueType: 'delta_link',
    );
  }

  return null;
}

Future<void> _migrateV20ToV21IntegrationsKeyValue(
  AppDatabase db,
  Migrator m,
) async {
  if (!await _sqliteTableExists(db, 'integrations_key_value')) {
    await m.createTable(db.integrationsKeyValue);
  }
  await _ensureIntegrationsKeyValueIndexes(db);

  if (!await _sqliteTableExists(db, 'config_key_values')) {
    return;
  }

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final legacyRows =
      await db.customSelect('SELECT key, value FROM config_key_values').get();
  final keysToDelete = <String>[];

  for (final row in legacyRows) {
    final legacyKey = row.read<String>('key');
    final value = row.read<String>('value');
    final mapped = await _mapLegacyIntegrationKvKey(db, legacyKey);
    if (mapped == null) {
      continue;
    }

    final integrationId = mapped.integrationId;
    final accountId = mapped.accountId;
    if (integrationId != null) {
      final exists = await db.customSelect(
        'SELECT 1 FROM integrations WHERE id = ? LIMIT 1',
        variables: [Variable<String>(integrationId)],
      ).getSingleOrNull();
      if (exists == null) {
        continue;
      }
    }
    if (accountId != null) {
      final exists = await db.customSelect(
        'SELECT 1 FROM integration_accounts WHERE id = ? LIMIT 1',
        variables: [Variable<String>(accountId)],
      ).getSingleOrNull();
      if (exists == null) {
        continue;
      }
    }

    keysToDelete.add(legacyKey);

    final IntegrationsKeyValueData? existing;
    if (integrationId != null) {
      existing = await (db.select(db.integrationsKeyValue)
            ..where(
              (t) => t.integrationId.equals(integrationId) & t.key.equals(mapped.key),
            ))
          .getSingleOrNull();
    } else {
      existing = await (db.select(db.integrationsKeyValue)
            ..where(
              (t) => t.accountId.equals(accountId!) & t.key.equals(mapped.key),
            ))
          .getSingleOrNull();
    }

    if (existing != null) {
      final existingId = existing.id;
      await (db.update(db.integrationsKeyValue)
            ..where((t) => t.id.equals(existingId)))
          .write(
        IntegrationsKeyValueCompanion(
          value: Value(value),
          valueType: Value(mapped.valueType),
          updatedAtMs: Value(nowMs),
        ),
      );
    } else {
      await db.into(db.integrationsKeyValue).insert(
            IntegrationsKeyValueCompanion.insert(
              integrationId: Value(integrationId),
              accountId: Value(accountId),
              key: mapped.key,
              value: value,
              valueType: Value(mapped.valueType),
              createdAtMs: nowMs,
              updatedAtMs: nowMs,
            ),
          );
    }
  }

  for (final k in keysToDelete) {
    await db.customStatement(
      'DELETE FROM config_key_values WHERE key = ?',
      [k],
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
