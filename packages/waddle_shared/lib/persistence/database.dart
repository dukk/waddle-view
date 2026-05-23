import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../config/integration_config_json.dart';
import '../theme/display_program_history_kv.dart';
import '../integration_accounts/integration_account_catalog.dart';
import '../integration_accounts/integration_accounts_configured_sql.dart';
import '../integration_accounts/integration_accounts_service.dart';
import '../persistence/config_json_documentation.dart';
import '../persistence/screen_config_migrate.dart';
import '../persistence/integration_type_label.dart';
import '../persistence/overlay_type_label.dart';
import '../persistence/screen_type_label.dart';
import '../persistence/ticker_type_label.dart';
import '../seed/tables/interests_locations_seed.dart';
import 'display_overlay_repository.dart';
import 'display_overlay_sql.dart';
import 'display_overlay_static_image_settings.dart';
import '../seed/tables/overlay_types_seed.dart';
import 'reject_term_defaults.dart';
import 'tables.dart';
import 'weather_location_category.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    ContentCategories,
    IntegrationTypes,
    IntegrationTypeRequiredAccounts,
    ScreenTypes,
    TickerTapeTypes,
    OverlayTypes,
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
    QuoterismQuotes,
    QuoterismQuoteCategories,
    InterestsTrivia,
    TriviaQuestions,
    TriviaGenerationBatches,
    CalendarEvents,
    CalendarEventCategories,
    InterestsLocations,
    WeatherCurrent,
    WeatherAlerts,
    Photos,
    PhotoCategories,
    Videos,
    VideoCategories,
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
    TaskLists,
    Tasks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 52;

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
      await customStatement(kEnsureOverlayTypesTableSql);
      await _ensureIntegrationsKeyValueIndexes(this);
      await ensureDefaultRejectTerms(this);
      await customStatement(kCreateIntegrationTypeRequiredAccountsTableSql);
      await seedIntegrationTypeRequiredAccounts(this);
      await customStatement(kCreateVIntegrationAccountsConfiguredViewSql);
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
        if (to == 21) {
          return;
        }
        from = 21;
      }
      if (from == 21 && to >= 22) {
        await _migrateV21ToV22DisplayProgramHistoryDepth(this);
        if (to == 22) {
          return;
        }
        from = 22;
      }
      if (from == 22 && to >= 23) {
        await _migrateV22ToV23IntegrationsAccountsReady(this);
        if (to == 23) {
          return;
        }
        from = 23;
      }
      if (from == 23 && to >= 24) {
        await _migrateV23ToV24DisplayEntityLabels(this);
        if (to == 24) {
          return;
        }
        from = 24;
      }
      if (from == 24 && to >= 25) {
        await _migrateV24ToV25CalendarEventCategories(this, m);
        if (to == 25) {
          return;
        }
        from = 25;
      }
      if (from == 25 && to >= 26) {
        await _migrateV25ToV26IntegrationTypes(this);
        if (to == 26) {
          return;
        }
        from = 26;
      }
      if (from == 26 && to >= 27) {
        await _migrateV26ToV27DisplayTypeRegistries(this);
        if (to == 27) {
          return;
        }
        from = 27;
      }
      if (from == 27 && to >= 28) {
        await _migrateV27ToV28TickerTapeTypesTable(this);
        if (to == 28) {
          return;
        }
        from = 28;
      }
      if (from == 28 && to >= 29) {
        await _migrateV28ToV29TickerTapeSlotTypes(this);
        if (to == 29) {
          return;
        }
        from = 29;
      }
      if (from == 29 && to >= 30) {
        await _migrateV29ToV30DropTickerTapeConfigKey(this);
        if (to == 30) {
          return;
        }
        from = 30;
      }
      if (from == 30 && to >= 31) {
        await _migrateV30ToV31StaticImageOverlayFromKv(this);
        if (to == 31) {
          return;
        }
        from = 31;
      }
      if (from == 31 && to >= 32) {
        await _migrateV31ToV32IntegrationAccountsConfiguredView(this);
        if (to == 32) {
          return;
        }
        from = 32;
      }
      if (from == 32 && to >= 33) {
        await _migrateV32ToV33ViewportReserveOverrides(this);
        if (to == 33) {
          return;
        }
        from = 33;
      }
      if (from == 33 && to >= 34) {
        await _migrateV33ToV34OverlayTypesCatalog(this);
        if (to == 34) {
          return;
        }
        from = 34;
      }
      if (from == 34 && to >= 35) {
        await _migrateV34ToV35OverlayTypesCatalog(this);
        if (to == 35) {
          return;
        }
        from = 35;
      }
      if (from == 35 && to >= 36) {
        await _migrateV35ToV36OverlayTypesCatalog(this);
        if (to == 36) {
          return;
        }
        from = 36;
      }
      if (from == 36 && to >= 37) {
        await _migrateV36ToV37OverlayTypesCatalog(this);
        if (to == 37) {
          return;
        }
        from = 37;
      }
      if (from == 37 && to >= 38) {
        await _migrateV37ToV38PhotoVideoCategories(this, m);
        if (to == 38) {
          return;
        }
        from = 38;
      }
      if (from == 38 && to >= 39) {
        await _migrateV38ToV39TrimLocationCatalog(this);
        if (to == 39) {
          return;
        }
        from = 39;
      }
      if (from == 39 && to >= 40) {
        await _migrateV39ToV40QrCodeOverlayType(this);
        if (to == 40) {
          return;
        }
        from = 40;
      }
      if (from == 40 && to >= 41) {
        await _migrateV40ToV41CloudDriftOverlayType(this);
        if (to == 41) {
          return;
        }
        from = 41;
      }
      if (from == 41 && to >= 42) {
        await _migrateV41ToV42NullableCuratorTickerOverrides(this);
        if (to == 42) {
          return;
        }
        from = 42;
      }
      if (from == 42 && to >= 43) {
        await _migrateV42ToV43DefaultBaseCurator(this);
        if (to == 43) {
          return;
        }
        from = 43;
      }
      if (from == 43 && to >= 44) {
        await _migrateV43ToV44OverlayDescription(this);
        if (to == 44) {
          return;
        }
        from = 44;
      }
      if (from == 44 && to >= 45) {
        await _migrateV44ToV45ManualEntrySource(this);
        if (to == 45) {
          return;
        }
        from = 45;
      }
      if (from == 45 && to >= 46) {
        await _migrateV45ToV46QuoterismQuotes(this, m);
        if (to == 46) {
          return;
        }
        from = 46;
      }
      if (from == 46 && to >= 47) {
        await _migrateV46ToV47CuratorScreensEnabled(this);
        if (to == 47) {
          return;
        }
        from = 47;
      }
      if (from == 47 && to >= 48) {
        await _migrateV47ToV48ScreenConfigJson(this);
        if (to == 48) {
          return;
        }
        from = 48;
      }
      if (from == 48 && to >= 49) {
        await _migrateV48ToV49TaskTables(this, m);
        if (to == 49) {
          return;
        }
        from = 49;
      }
      if (from == 49 && to >= 50) {
        await _migrateV49ToV50StockSymbolCategories(this);
        if (to == 50) {
          return;
        }
        from = 50;
      }
      if (from == 50 && to >= 51) {
        await _migrateV50ToV51InterestsStockSymbolCategoryBackfill(this);
        if (to == 51) {
          return;
        }
        from = 51;
      }
      if (from == 51 && to >= 52) {
        await _migrateV51ToV52CuratorMemberOpsAndSortRebalance(this);
        if (to == 52) {
          return;
        }
        from = 52;
      }
      throw UnsupportedError(
        'Unsupported database upgrade from version $from to $to. '
        'Delete the SQLite file and reinstall (fresh seed).',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _ensureCuratorCategoriesTable(this);
      await _ensureCuratorRejectedTermsTable(this);
      await _ensureCuratorConfigurationsTickerEnabled(this);
      await _ensureCuratorConfigurationsScreensEnabled(this);
      await _ensureCuratorConfigurationsTickerProgramDuration(this);
      await _ensureCuratorConfigurationsTickerPixelsPerSecond(this);
      await _ensureIntegrationAccountsConfiguredView(this);
      await _ensureAdoptionApiTables(this);
      await _ensureInterestsStockSymbolCategoriesPopulated(this);
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
const String kDefaultJokeJokeapiIntegrationId = 'default_joke_jokeapi';
const String kDefaultGeneralOpenAiIntegrationId = 'default_general_openai';
const String kDefaultTriviaOpenAiIntegrationId = 'default_trivia_openai';
const String kDefaultTriviaOpenTdbIntegrationId = 'default_trivia_opentdb';
const String kDefaultWeatherOpenWeatherMapIntegrationId =
    'default_weather_openweathermap';
const String kDefaultWeatherAlertsNwsIntegrationId =
    'default_weather_alerts_nws';
const String kDefaultWeatherOpenMeteoIntegrationId =
    'default_weather_openmeteo';
const String kDefaultAirQualityOpenMeteoIntegrationId =
    'default_air_quality_openmeteo';
const String kDefaultPhotoPexelsIntegrationId = 'default_photo_pexels';
const String kDefaultVideoPexelsIntegrationId = 'default_video_pexels';
const String kDefaultStockFinnhubIntegrationId = 'default_stock_finnhub';
const String kDefaultHomeAssistantIntegrationId = 'default_home_assistant';
const String kDefaultTasksTrelloIntegrationId = 'default_tasks_trello';
const String kDefaultCalendarGoogleIntegrationId = 'default_calendar_google';
const String kDefaultCalendarOutlookIntegrationId = 'default_calendar_outlook';
const String kDefaultCalendarIcalIntegrationId = 'default_calendar_ical';
const String kDefaultCalendarMealviewerIntegrationId =
    'default_calendar_mealviewer';
const String kDefaultPhotoOneDriveIntegrationId = 'default_photo_onedrive';
const String kDefaultVideoOneDriveIntegrationId = 'default_video_onedrive';
const String kDefaultPhotoFlickrIntegrationId = 'default_photo_flickr';
const String kDefaultPhotoGoogleIntegrationId = 'default_photo_google';
const String kDefaultVideoGoogleIntegrationId = 'default_video_google';
const String kDefaultPhotoBingIotdIntegrationId =
    'default_photo_bing_image_of_the_day';
const String kDefaultPhotoNasaApodIntegrationId = 'default_photo_nasa_apod';
const String kDefaultPhotoNasaMarsRoverIntegrationId =
    'default_photo_nasa_mars_rover';
const String kDefaultPhotoNasaEarthImageryIntegrationId =
    'default_photo_nasa_earth_imagery';
const String kDefaultQuoteQuoterismIntegrationId = 'default_quote_quoterism';

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

  final columns = await db
      .customSelect('PRAGMA table_info(integrations)')
      .get();
  final hasProviderType = columns.any(
    (c) => c.read<String>('name') == 'provider_type',
  );
  final hasIntegrationType = columns.any(
    (c) => c.read<String>('name') == 'integration_type',
  );
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

  Future<void> updateDataProviderIfTable(
    String table,
    String set,
    String where,
  ) async {
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

  final pexelsRow = await db
      .customSelect(
        'SELECT * FROM integrations WHERE id = ? OR integration_type = ? LIMIT 1',
        variables: [
          const Variable<String>('media_pexels'),
          const Variable<String>('media_pexels'),
        ],
      )
      .getSingleOrNull();
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
    await _migrateIntegrationSecretKeys(
      db,
      oldId,
      kDefaultPhotoPexelsIntegrationId,
    );
    await _migrateConfigKvPrefix(db, oldId, kDefaultPhotoPexelsIntegrationId);

    final videoExists = await db
        .customSelect(
          'SELECT 1 FROM integrations WHERE id = ? LIMIT 1',
          variables: [Variable<String>(kDefaultVideoPexelsIntegrationId)],
        )
        .getSingleOrNull();
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

  final onedriveRow = await db
      .customSelect(
        'SELECT * FROM integrations WHERE id = ? OR integration_type = ? LIMIT 1',
        variables: [
          const Variable<String>('media_onedrive'),
          const Variable<String>('media_onedrive'),
        ],
      )
      .getSingleOrNull();
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
    await _migrateIntegrationSecretKeys(
      db,
      oldId,
      kDefaultPhotoOneDriveIntegrationId,
    );
    await _migrateConfigKvPrefix(db, oldId, kDefaultPhotoOneDriveIntegrationId);

    final videoExists = await db
        .customSelect(
          'SELECT 1 FROM integrations WHERE id = ? LIMIT 1',
          variables: [Variable<String>(kDefaultVideoOneDriveIntegrationId)],
        )
        .getSingleOrNull();
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
    'joke_jokeapi': kDefaultJokeJokeapiIntegrationId,
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
    'calendar_mealviewer': kDefaultCalendarMealviewerIntegrationId,
    'media_flickr': kDefaultPhotoFlickrIntegrationId,
    'photo_flickr': kDefaultPhotoFlickrIntegrationId,
    'media_bing_iotd': kDefaultPhotoBingIotdIntegrationId,
    'photo_bing_image_of_the_day': kDefaultPhotoBingIotdIntegrationId,
  };
  for (final e in idMigrations.entries) {
    final exists = await db
        .customSelect(
          'SELECT 1 FROM integrations WHERE id = ? LIMIT 1',
          variables: [Variable<String>(e.key)],
        )
        .getSingleOrNull();
    if (exists == null) {
      continue;
    }
    final targetTaken = await db
        .customSelect(
          'SELECT 1 FROM integrations WHERE id = ? LIMIT 1',
          variables: [Variable<String>(e.value)],
        )
        .getSingleOrNull();
    if (targetTaken != null) {
      continue;
    }
    await db.customStatement('UPDATE integrations SET id = ? WHERE id = ?', [
      e.value,
      e.key,
    ]);
    await _migrateIntegrationSecretKeys(db, e.key, e.value);
    await _migrateConfigKvPrefix(db, e.key, e.value);
  }
}

Future<String?> _integrationSecretsStorageKeyColumn(AppDatabase db) async {
  final columns = await db
      .customSelect('PRAGMA table_info(integration_secrets)')
      .get();
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
  final columns = await db
      .customSelect('PRAGMA table_info(integration_secrets)')
      .get();
  final hasNonce = columns.any((c) => c.read<String>('name') == 'nonce');
  if (hasNonce) {
    final row = await db
        .customSelect(
          'SELECT ciphertext, nonce, updated_at_ms FROM integration_secrets '
          'WHERE $keyColumn = ?',
          variables: [Variable<String>(fromKey)],
        )
        .getSingleOrNull();
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
  final row = await db
      .customSelect(
        'SELECT ciphertext, updated_at_ms FROM integration_secrets WHERE $keyColumn = ?',
        variables: [Variable<String>(fromKey)],
      )
      .getSingleOrNull();
  if (row == null) {
    return;
  }
  await db.customStatement(
    'INSERT OR REPLACE INTO integration_secrets '
    '($keyColumn, ciphertext, updated_at_ms) VALUES (?, ?, ?)',
    [toKey, row.read<Uint8List>('ciphertext'), row.read<int>('updated_at_ms')],
  );
}

Future<bool> _sqliteTableExists(AppDatabase db, String tableName) async {
  final row = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
        variables: [Variable<String>(tableName)],
      )
      .getSingleOrNull();
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

/// Ensures adoption REST tables exist (pairing flow + API key hashes).
///
/// Fresh databases get these from [MigrationStrategy.onCreate]. Upgraded
/// databases at schema 48 may have skipped the v47 cutover when adoption
/// migrations were dropped — this idempotent guard runs on every open.
Future<void> _ensureAdoptionApiTables(AppDatabase db) async {
  final migrator = Migrator(db);

  if (!await _sqliteTableExists(db, 'adoption_pending')) {
    await migrator.createTable(db.adoptionPending);
  }

  if (!await _sqliteTableExists(db, 'api_clients')) {
    await migrator.createTable(db.apiClients);
    await db.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS api_clients_identifier '
      'ON api_clients (identifier)',
    );
    await db.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS api_clients_api_key_hash '
      'ON api_clients (api_key_hash)',
    );
  } else if (!await _sqliteColumnExists(db, 'api_clients', 'referrer_origin')) {
    await db.customStatement(
      'ALTER TABLE api_clients ADD COLUMN referrer_origin TEXT',
    );
  }

  if (!await _sqliteTableExists(db, 'cors_allowed_origins')) {
    await migrator.createTable(db.corsAllowedOrigins);
  }
}

/// Ensures [ContentCategories] is stored as `curator_categories` (renamed from
/// legacy `content_categories` on upgraded databases).
Future<void> _ensureCuratorCategoriesTable(
  AppDatabase db, {
  Migrator? migrator,
}) async {
  if (await _sqliteTableExists(db, 'curator_categories')) {
    return;
  }
  if (await _sqliteTableExists(db, 'content_categories')) {
    await db.customStatement(
      'DROP VIEW IF EXISTS v_integration_accounts_configured',
    );
    await db.customStatement(
      'ALTER TABLE content_categories RENAME TO curator_categories',
    );
    await _ensureIntegrationAccountsConfiguredView(db);
    return;
  }
  final m = migrator ?? Migrator(db);
  await m.createTable(db.contentCategories);
}

/// Ensures [RejectTerms] is stored as `curator_rejected_terms`.
Future<void> _ensureCuratorRejectedTermsTable(
  AppDatabase db, {
  Migrator? migrator,
}) async {
  if (await _sqliteTableExists(db, 'curator_rejected_terms')) {
    return;
  }
  if (await _sqliteTableExists(db, 'reject_terms')) {
    await db.customStatement(
      'ALTER TABLE reject_terms RENAME TO curator_rejected_terms',
    );
    return;
  }
  final m = migrator ?? Migrator(db);
  await m.createTable(db.rejectTerms);
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
  final rows = await db
      .customSelect('SELECT id, name FROM interests_locations')
      .get();
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
  if (!await _sqliteColumnExists(
    db,
    'interests_locations',
    'include_local_news',
  )) {
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
  if (!await _sqliteColumnExists(
    db,
    'curator_configurations',
    'ticker_enabled',
  )) {
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

Future<void> _migrateV16ToV17CuratorTickerProgramDuration(
  AppDatabase db,
) async {
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
  final hasCuratorMembers = await _sqliteTableExists(
    db,
    'curator_configuration_members',
  );
  if (hasCuratorMembers) {
    await db.customStatement(
      'UPDATE curator_configuration_members SET entity_id = ? '
      "WHERE entity_type = ? AND entity_id = 'default_birthday_example_may_13'",
      <Object?>[kDefaultBirthdayConfettiOverlayId, kCuratorMemberEntityOverlay],
    );
  }
  await db.customStatement(
    'UPDATE overlays SET id = ?, name = ? WHERE id = ?',
    <Object?>[
      kDefaultBirthdayConfettiOverlayId,
      'Default Birthday Confetti',
      'default_birthday_example_may_13',
    ],
  );
  if (hasCuratorMembers) {
    await db.customStatement(
      'UPDATE curator_configuration_members SET entity_id = ? '
      "WHERE entity_type = ? AND entity_id = 'default_bouncing_message_may_13'",
      <Object?>[
        kDefaultWattleViewsBirthdayMessageOverlayId,
        kCuratorMemberEntityOverlay,
      ],
    );
  }
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
      'ticker_program_duration_seconds INTEGER',
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
      'ticker_pixels_per_second INTEGER',
    );
  }
}

Future<void> _migrateV18ToV19CuratorTickerPixelsPerSecond(
  AppDatabase db,
) async {
  await _ensureCuratorConfigurationsTickerPixelsPerSecond(db);
  if (!await _sqliteTableExists(db, 'curator_configurations')) {
    return;
  }
  var migratedPx = _kCuratorTickerPixelsPerSecondDefault;
  if (await _sqliteTableExists(db, 'config_key_values')) {
    final kvRow = await db
        .customSelect(
          "SELECT value FROM config_key_values WHERE key = 'curator.ticker.newsPixelsPerSecond' LIMIT 1",
        )
        .getSingleOrNull();
    final raw = kvRow?.read<String?>('value')?.trim();
    if (raw != null && raw.isNotEmpty) {
      migratedPx = _clampCuratorTickerPixelsPerSecond(
        int.tryParse(raw) ?? migratedPx,
      );
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
  final hasBaseUrl = await _sqliteColumnExists(db, 'integrations', 'base_url');
  final hasExample = await _sqliteColumnExists(
    db,
    'integrations',
    'example_config_json',
  );
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
  await db.customStatement(
    'ALTER TABLE integrations_new RENAME TO integrations',
  );
  await db.customStatement('PRAGMA foreign_keys = ON');
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
  final links = await db
      .customSelect(
        '''
SELECT l.integration_id AS integration_id
FROM integration_account_links l
INNER JOIN integrations i ON i.id = l.integration_id
WHERE l.account_id = ?
  AND i.integration_type IN ('photo_onedrive', 'video_onedrive')
''',
        variables: [Variable<String>(accountKey)],
      )
      .get();
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
      'calendar_mealviewer' => kDefaultCalendarMealviewerIntegrationId,
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

  const outlookPromptPrefix =
      'provider.calendar_outlook.last_device_prompt_ms.';
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
    final integrationId = await _resolveOnedriveIntegrationIdForAccount(
      db,
      accountKey,
    );
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
  final legacyRows = await db
      .customSelect('SELECT key, value FROM config_key_values')
      .get();
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
      final exists = await db
          .customSelect(
            'SELECT 1 FROM integrations WHERE id = ? LIMIT 1',
            variables: [Variable<String>(integrationId)],
          )
          .getSingleOrNull();
      if (exists == null) {
        continue;
      }
    }
    if (accountId != null) {
      final exists = await db
          .customSelect(
            'SELECT 1 FROM integration_accounts WHERE id = ? LIMIT 1',
            variables: [Variable<String>(accountId)],
          )
          .getSingleOrNull();
      if (exists == null) {
        continue;
      }
    }

    keysToDelete.add(legacyKey);

    final IntegrationsKeyValueData? existing;
    if (integrationId != null) {
      existing =
          await (db.select(db.integrationsKeyValue)..where(
                (t) =>
                    t.integrationId.equals(integrationId) &
                    t.key.equals(mapped.key),
              ))
              .getSingleOrNull();
    } else {
      existing =
          await (db.select(db.integrationsKeyValue)..where(
                (t) =>
                    t.accountId.equals(accountId!) & t.key.equals(mapped.key),
              ))
              .getSingleOrNull();
    }

    if (existing != null) {
      final existingId = existing.id;
      await (db.update(
        db.integrationsKeyValue,
      )..where((t) => t.id.equals(existingId))).write(
        IntegrationsKeyValueCompanion(
          value: Value(value),
          valueType: Value(mapped.valueType),
          updatedAtMs: Value(nowMs),
        ),
      );
    } else {
      await db
          .into(db.integrationsKeyValue)
          .insert(
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
    await db.customStatement('DELETE FROM config_key_values WHERE key = ?', [
      k,
    ]);
  }
}

/// Renames `name` → `label` on screens/ticker_tapes/overlays; photos `pexels_page_url` → `page_url`.
Future<void> _migrateV23ToV24DisplayEntityLabels(AppDatabase db) async {
  if (await _sqliteTableExists(db, 'screens') &&
      await _sqliteColumnExists(db, 'screens', 'name') &&
      !await _sqliteColumnExists(db, 'screens', 'label')) {
    await db.customStatement('ALTER TABLE screens RENAME COLUMN name TO label');
  }
  if (await _sqliteTableExists(db, 'ticker_tapes') &&
      await _sqliteColumnExists(db, 'ticker_tapes', 'name') &&
      !await _sqliteColumnExists(db, 'ticker_tapes', 'label')) {
    await db.customStatement(
      'ALTER TABLE ticker_tapes RENAME COLUMN name TO label',
    );
  }
  if (await _sqliteTableExists(db, 'overlays') &&
      await _sqliteColumnExists(db, 'overlays', 'name') &&
      !await _sqliteColumnExists(db, 'overlays', 'label')) {
    await db.customStatement(
      'ALTER TABLE overlays RENAME COLUMN name TO label',
    );
  }
  if (await _sqliteTableExists(db, 'photos') &&
      await _sqliteColumnExists(db, 'photos', 'pexels_page_url') &&
      !await _sqliteColumnExists(db, 'photos', 'page_url')) {
    await db.customStatement(
      'ALTER TABLE photos RENAME COLUMN pexels_page_url TO page_url',
    );
  }
}

/// Extracts per-type schema/labels into [IntegrationTypes]; drops duplicated columns on [Integrations].
Future<void> _migrateV25ToV26IntegrationTypes(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'integrations')) {
    return;
  }
  await db.customStatement('PRAGMA foreign_keys = OFF');
  await db.customStatement('''
CREATE TABLE IF NOT EXISTS integration_types (
  integration_type TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  config_json_schema TEXT,
  requires_accounts INTEGER NOT NULL DEFAULT 0 CHECK (requires_accounts IN (0, 1))
)
''');

  final typeSchemas = <String, String?>{};
  final integrationRows = await db
      .customSelect('SELECT * FROM integrations')
      .get();
  for (final row in integrationRows) {
    final type = row.read<String>('integration_type');
    final schema = row.read<String?>('config_json_schema');
    if (schema != null && schema.trim().isNotEmpty) {
      typeSchemas.putIfAbsent(type, () => schema);
    }
  }

  final allTypes = <String>{
    ...typeSchemas.keys,
    ...kProviderConfigJsonMeta.keys,
    'news_facebook',
    'news_twitter',
    'news_linkedin',
  };

  for (final integrationType in allTypes) {
    final schema =
        typeSchemas[integrationType] ??
        providerConfigJsonDocForType(integrationType).schema;
    final requires = integrationAccountTypesRequiredForIntegration(
      integrationType,
    ).isNotEmpty;
    final label = integrationTypeLabel(integrationType);
    await db.customStatement(
      'INSERT OR REPLACE INTO integration_types '
      '(integration_type, label, config_json_schema, requires_accounts) '
      'VALUES (?, ?, ?, ?)',
      [integrationType, label, schema, requires ? 1 : 0],
    );
  }

  final hasConfigSchema = await _sqliteColumnExists(
    db,
    'integrations',
    'config_json_schema',
  );
  final hasRequiresAccounts = await _sqliteColumnExists(
    db,
    'integrations',
    'requires_accounts',
  );
  if (!hasConfigSchema && !hasRequiresAccounts) {
    await db.customStatement('PRAGMA foreign_keys = ON');
    return;
  }

  await db.customStatement(
    'DROP INDEX IF EXISTS idx_integrations_enabled_accounts',
  );
  await db.customStatement('''
CREATE TABLE integrations_new (
  id TEXT NOT NULL PRIMARY KEY,
  integration_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  config_json TEXT,
  accounts_ready INTEGER NOT NULL DEFAULT 1 CHECK (accounts_ready IN (0, 1))
)
''');
  for (final row in integrationRows) {
    await db.customStatement(
      'INSERT INTO integrations_new '
      '(id, integration_type, enabled, poll_seconds, config_json, accounts_ready) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        row.read<String>('id'),
        row.read<String>('integration_type'),
        row.read<int>('enabled'),
        row.read<int>('poll_seconds'),
        row.read<String?>('config_json'),
        row.read<int?>('accounts_ready') ?? 1,
      ],
    );
  }
  await db.customStatement('DROP TABLE integrations');
  await db.customStatement(
    'ALTER TABLE integrations_new RENAME TO integrations',
  );
  await db.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_integrations_enabled_accounts '
    'ON integrations (enabled, accounts_ready)',
  );
  await db.customStatement('PRAGMA foreign_keys = ON');
}

/// Adds [calendar_event_categories] and backfills from legacy single [CalendarEvents.categoryId].
Future<void> _migrateV24ToV25CalendarEventCategories(
  AppDatabase db,
  Migrator m,
) async {
  await m.createTable(db.calendarEventCategories);
  if (!await _sqliteTableExists(db, 'calendar_events')) {
    return;
  }
  await db.customStatement('''
INSERT OR IGNORE INTO calendar_event_categories (event_id, category_id)
SELECT id, category_id FROM calendar_events WHERE category_id IS NOT NULL
''');
}

Future<void> _migrateV22ToV23IntegrationsAccountsReady(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'integrations')) {
    return;
  }
  if (!await _sqliteColumnExists(db, 'integrations', 'requires_accounts')) {
    await db.customStatement(
      'ALTER TABLE integrations ADD COLUMN requires_accounts INTEGER NOT NULL DEFAULT 0',
    );
  }
  if (!await _sqliteColumnExists(db, 'integrations', 'accounts_ready')) {
    await db.customStatement(
      'ALTER TABLE integrations ADD COLUMN accounts_ready INTEGER NOT NULL DEFAULT 1',
    );
  }
  await db.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_integrations_enabled_accounts '
    'ON integrations (enabled, accounts_ready)',
  );
  await _backfillIntegrationsAccountsReadyColumnsV23(db);
}

Future<void> _migrateV21ToV22DisplayProgramHistoryDepth(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'config_key_values')) {
    return;
  }
  final existing = await db
      .customSelect(
        'SELECT 1 FROM config_key_values WHERE key = ? LIMIT 1',
        variables: [Variable<String>(kDisplayProgramHistoryDepthKvKey)],
      )
      .getSingleOrNull();
  if (existing != null) {
    return;
  }

  var depth = kDefaultDisplayProgramHistoryDepth;
  if (await _sqliteTableExists(db, 'curator_configurations')) {
    final defaultRow = await db
        .customSelect(
          'SELECT history_depth FROM curator_configurations '
          'WHERE default_config = 1 LIMIT 1',
        )
        .getSingleOrNull();
    if (defaultRow != null) {
      depth = normalizeDisplayProgramHistoryDepth(
        '${defaultRow.read<int>('history_depth')}',
      );
    }
  }

  await db
      .into(db.configKeyValues)
      .insert(
        ConfigKeyValuesCompanion.insert(
          key: kDisplayProgramHistoryDepthKvKey,
          value: '$depth',
        ),
      );
}

/// Extracts per-type schema/labels into [ScreenTypes], [TickerTapeTypes], [OverlayTypes];
/// drops duplicated columns on instance tables.
Future<void> _migrateV26ToV27DisplayTypeRegistries(AppDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');

  await db.customStatement('''
CREATE TABLE IF NOT EXISTS screen_types (
  screen_type TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  config_json_schema TEXT
)
''');

  final screenTypeSchemas = <String, String?>{};
  if (await _sqliteTableExists(db, 'screens')) {
    final screenRows = await db.customSelect('SELECT * FROM screens').get();
    for (final row in screenRows) {
      final type = row.read<String>('screen_type');
      final schema = row.read<String?>('config_json_schema');
      if (schema != null && schema.trim().isNotEmpty) {
        screenTypeSchemas.putIfAbsent(type, () => schema);
      }
    }
    final allScreenTypes = <String>{
      ...screenTypeSchemas.keys,
      ...kScreenLayoutWidgetTypes,
    };
    for (final screenType in allScreenTypes) {
      final schema =
          screenTypeSchemas[screenType] ??
          screenConfigJsonDocForType(screenType).schema;
      await db.customStatement(
        'INSERT OR REPLACE INTO screen_types '
        '(screen_type, label, config_json_schema) VALUES (?, ?, ?)',
        [screenType, screenTypeLabel(screenType), schema],
      );
    }

    final hasScreenSchema = await _sqliteColumnExists(
      db,
      'screens',
      'config_json_schema',
    );
    if (hasScreenSchema) {
      await db.customStatement('''
CREATE TABLE screens_new (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  screen_type TEXT NOT NULL,
  config_json TEXT NOT NULL DEFAULT '{}',
  min_dwell_seconds INTEGER NOT NULL DEFAULT 8,
  max_dwell_seconds INTEGER NOT NULL DEFAULT 15,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  min_gap_between_shows_seconds INTEGER NOT NULL DEFAULT 0,
  min_placements_per_program INTEGER NOT NULL DEFAULT 0,
  max_placements_per_program INTEGER,
  data_key TEXT NOT NULL DEFAULT ''
)
''');
      for (final row in screenRows) {
        await db.customStatement(
          'INSERT INTO screens_new ('
          'id, label, description, screen_type, config_json, '
          'min_dwell_seconds, max_dwell_seconds, frequency_weight, '
          'min_gap_between_shows_seconds, min_placements_per_program, '
          'max_placements_per_program, data_key) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            row.read<String>('id'),
            row.read<String>('label'),
            row.read<String>('description'),
            row.read<String>('screen_type'),
            row.read<String>('config_json'),
            row.read<int>('min_dwell_seconds'),
            row.read<int>('max_dwell_seconds'),
            row.read<int>('frequency_weight'),
            row.read<int>('min_gap_between_shows_seconds'),
            row.read<int>('min_placements_per_program'),
            row.read<int?>('max_placements_per_program'),
            row.read<String>('data_key'),
          ],
        );
      }
      await db.customStatement('DROP TABLE screens');
      await db.customStatement('ALTER TABLE screens_new RENAME TO screens');
    }
  }

  await db.customStatement('''
CREATE TABLE IF NOT EXISTS ticker_tape_types (
  ticker_type TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  config_json_schema TEXT
)
''');

  final tickerTypeSchemas = <String, String?>{};
  if (await _sqliteTableExists(db, 'ticker_tapes')) {
    final tickerRows = await db
        .customSelect('SELECT * FROM ticker_tapes')
        .get();
    for (final row in tickerRows) {
      final type = row.read<String>('ticker_type');
      final schema = row.read<String?>('config_json_schema');
      if (schema != null && schema.trim().isNotEmpty) {
        tickerTypeSchemas.putIfAbsent(type, () => schema);
      }
    }
    final allTickerTypes = <String>{
      ...tickerTypeSchemas.keys,
      ...kTickerSlotDefinitionTypes,
    };
    for (final tickerType in allTickerTypes) {
      final schema =
          tickerTypeSchemas[tickerType] ??
          tickerSlotConfigJsonDocForType(tickerType).schema;
      await db.customStatement(
        'INSERT OR REPLACE INTO ticker_tape_types '
        '(ticker_type, label, config_json_schema) VALUES (?, ?, ?)',
        [tickerType, tickerTypeLabel(tickerType), schema],
      );
    }

    final hasTickerSchema = await _sqliteColumnExists(
      db,
      'ticker_tapes',
      'config_json_schema',
    );
    if (hasTickerSchema) {
      await db.customStatement('''
CREATE TABLE ticker_tapes_new (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  ticker_type TEXT NOT NULL,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  sort_order INTEGER NOT NULL DEFAULT 0,
  config_json TEXT NOT NULL DEFAULT '{}'
)
''');
      for (final row in tickerRows) {
        await db.customStatement(
          'INSERT INTO ticker_tapes_new ('
          'id, label, description, ticker_type, frequency_weight, '
          'sort_order, config_json) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            row.read<String>('id'),
            row.read<String>('label'),
            row.read<String>('description'),
            row.read<String>('ticker_type'),
            row.read<int>('frequency_weight'),
            row.read<int>('sort_order'),
            row.read<String>('config_json'),
          ],
        );
      }
      await db.customStatement('DROP TABLE ticker_tapes');
      await db.customStatement(
        'ALTER TABLE ticker_tapes_new RENAME TO ticker_tapes',
      );
    }
  }

  await db.customStatement(kEnsureOverlayTypesTableSql);

  final overlayTypeSchemas = <String, String?>{};
  if (await _sqliteTableExists(db, 'overlays')) {
    final overlayRows = await db.customSelect('SELECT * FROM overlays').get();
    for (final row in overlayRows) {
      final type = row.read<String>('overlay_type');
      final schema = row.read<String?>('config_json_schema');
      if (schema != null && schema.trim().isNotEmpty) {
        overlayTypeSchemas.putIfAbsent(type, () => schema);
      }
    }
    final allOverlayTypes = <String>{
      ...overlayTypeSchemas.keys,
      ...kBuiltinOverlayTypes,
    };
    for (final overlayType in allOverlayTypes) {
      final schema =
          overlayTypeSchemas[overlayType] ??
          displayOverlayConfigJsonDocForType(overlayType).schema;
      await db.customStatement(
        'INSERT OR REPLACE INTO overlay_types '
        '(overlay_type, label, config_json_schema) VALUES (?, ?, ?)',
        [overlayType, overlayTypeLabel(overlayType), schema],
      );
    }

    final hasOverlaySchema = await _sqliteColumnExists(
      db,
      'overlays',
      'config_json_schema',
    );
    if (hasOverlaySchema) {
      await db.customStatement('''
CREATE TABLE overlays_new (
  id TEXT NOT NULL PRIMARY KEY,
  overlay_type TEXT NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  config_json TEXT NOT NULL DEFAULT '{}'
)
''');
      for (final row in overlayRows) {
        await db.customStatement(
          'INSERT INTO overlays_new (id, overlay_type, label, config_json) '
          'VALUES (?, ?, ?, ?)',
          [
            row.read<String>('id'),
            row.read<String>('overlay_type'),
            row.read<String>('label'),
            row.read<String>('config_json'),
          ],
        );
      }
      await db.customStatement('DROP TABLE overlays');
      await db.customStatement('ALTER TABLE overlays_new RENAME TO overlays');
    }
  } else {
    for (final overlayType in kBuiltinOverlayTypes) {
      final doc = displayOverlayConfigJsonDocForType(overlayType);
      await db.customStatement(
        'INSERT OR REPLACE INTO overlay_types '
        '(overlay_type, label, config_json_schema) VALUES (?, ?, ?)',
        [overlayType, overlayTypeLabel(overlayType), doc.schema],
      );
    }
  }

  await db.customStatement('PRAGMA foreign_keys = ON');
}

/// Renames legacy `ticker_types` registry table to [TickerTapeTypes] SQL name.
Future<void> _migrateV27ToV28TickerTapeTypesTable(AppDatabase db) async {
  if (await _sqliteTableExists(db, 'ticker_types') &&
      !await _sqliteTableExists(db, 'ticker_tape_types')) {
    await db.customStatement(
      'ALTER TABLE ticker_types RENAME TO ticker_tape_types',
    );
  }
}

/// Removes `quote`/`custom` ticker types, migrates tapes to `static_text`, and
/// strips weather/news fallback keys from [TickerTapes.configJson].
Future<void> _migrateV28ToV29TickerTapeSlotTypes(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'ticker_tapes')) {
    return;
  }

  final kv = <String, String>{};
  if (await _sqliteTableExists(db, 'config_key_values')) {
    final kvRows = await db
        .customSelect(
          "SELECT key, value FROM config_key_values WHERE key LIKE 'ticker.marquee.%'",
        )
        .get();
    for (final row in kvRows) {
      kv[row.read<String>('key')] = row.read<String>('value');
    }
  }

  final tapes = await db.customSelect('SELECT * FROM ticker_tapes').get();
  for (final row in tapes) {
    final id = row.read<String>('id');
    final originalType = row.read<String>('ticker_type');
    var configJson = row.read<String>('config_json');
    final configKey = row.read<String?>('config_key');

    if (originalType == 'quote' || originalType == 'custom') {
      configJson = jsonEncode(
        _staticTextConfigFromLegacyTape(
          configJson,
          configKey: configKey,
          kv: kv,
          wasCustom: originalType == 'custom',
        ),
      );
      await db.customStatement(
        'UPDATE ticker_tapes SET ticker_type = ?, config_json = ?, '
        'config_key = NULL WHERE id = ?',
        ['static_text', configJson, id],
      );
    } else if (originalType == 'weather' || originalType == 'news') {
      configJson = jsonEncode(_stripTickerTapeFallbackKeys(configJson));
      await db.customStatement(
        'UPDATE ticker_tapes SET config_json = ? WHERE id = ?',
        [configJson, id],
      );
    }
  }

  final registryTable = await _sqliteTableExists(db, 'ticker_tape_types')
      ? 'ticker_tape_types'
      : (await _sqliteTableExists(db, 'ticker_types') ? 'ticker_types' : null);
  if (registryTable != null) {
    await db.customStatement(
      "DELETE FROM $registryTable WHERE ticker_type IN ('quote', 'custom')",
    );
    for (final tickerType in kTickerSlotDefinitionTypes) {
      final schema = tickerSlotConfigJsonDocForType(tickerType).schema;
      await db.customStatement(
        'INSERT OR REPLACE INTO $registryTable '
        '(ticker_type, label, config_json_schema) VALUES (?, ?, ?)',
        [tickerType, tickerTypeLabel(tickerType), schema],
      );
    }
  }
}

Map<String, Object?> _parseTickerTapeConfigJsonMap(String rawConfigJson) {
  final t = rawConfigJson.trim();
  if (t.isEmpty || t == '{}') {
    return <String, Object?>{};
  }
  try {
    final decoded = jsonDecode(t);
    if (decoded is! Map) {
      return <String, Object?>{};
    }
    return decoded.map((k, Object? v) => MapEntry(k.toString(), v));
  } on Object {
    return <String, Object?>{};
  }
}

Map<String, String> _stripTickerTapeFallbackKeys(String rawConfigJson) {
  final m = _parseTickerTapeConfigJsonMap(rawConfigJson);
  m.remove('fallbackText');
  m.remove('ticker.marquee.weather');
  m.remove('ticker.marquee.news');
  m.remove('ticker.marquee.quote');
  return m.map((k, v) => MapEntry(k, v?.toString() ?? ''));
}

Map<String, String> _staticTextConfigFromLegacyTape(
  String rawConfigJson, {
  String? configKey,
  required Map<String, String> kv,
  required bool wasCustom,
}) {
  final m = _parseTickerTapeConfigJsonMap(rawConfigJson);
  var text = (m['text'] as String?)?.trim() ?? '';
  if (text.isEmpty) {
    text = (m['fallbackText'] as String?)?.trim() ?? '';
  }
  if (text.isEmpty) {
    final legacyQuote = m['ticker.marquee.quote'];
    if (legacyQuote is String && legacyQuote.trim().isNotEmpty) {
      text = legacyQuote.trim();
    }
  }
  if (text.isEmpty && wasCustom) {
    final key = configKey?.trim();
    if (key != null && key.isNotEmpty) {
      text = kv[key]?.trim() ?? '';
    }
    if (text.isEmpty) {
      final fromConfig =
          m.entries
              .where((e) => e.key.startsWith('ticker.marquee.'))
              .map((e) => e.value?.toString().trim() ?? '')
              .where((s) => s.isNotEmpty)
              .toList()
            ..sort();
      if (fromConfig.isNotEmpty) {
        text = fromConfig.join(' · ');
      }
    }
    if (text.isEmpty) {
      final keys =
          kv.keys.where((k) => k.startsWith('ticker.marquee.')).toList()
            ..sort();
      final lines = keys
          .map((k) => kv[k]!.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (lines.isNotEmpty) {
        text = lines.join(' · ');
      }
    }
  }
  return {'text': text};
}

/// Drops legacy [TickerTapes.configKey] column from `ticker_tapes`.
Future<void> _migrateV29ToV30DropTickerTapeConfigKey(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'ticker_tapes')) {
    return;
  }
  if (!await _sqliteColumnExists(db, 'ticker_tapes', 'config_key')) {
    return;
  }

  final kv = <String, String>{};
  if (await _sqliteTableExists(db, 'config_key_values')) {
    final kvRows = await db
        .customSelect(
          "SELECT key, value FROM config_key_values WHERE key LIKE 'ticker.marquee.%'",
        )
        .get();
    for (final row in kvRows) {
      kv[row.read<String>('key')] = row.read<String>('value');
    }
  }

  final tapes = await db.customSelect('SELECT * FROM ticker_tapes').get();
  final migrated = <List<Object?>>[];
  for (final row in tapes) {
    var configJson = row.read<String>('config_json');
    final configKey = row.read<String?>('config_key');
    final key = configKey?.trim();
    if (key != null && key.isNotEmpty) {
      final m = _parseTickerTapeConfigJsonMap(configJson);
      final text = (m['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) {
        final fromKv = kv[key]?.trim() ?? '';
        if (fromKv.isNotEmpty) {
          m['text'] = fromKv;
          configJson = jsonEncode(m);
        }
      }
    }
    migrated.add([
      row.read<String>('id'),
      row.read<String>('label'),
      row.read<String>('description'),
      row.read<String>('ticker_type'),
      row.read<int>('frequency_weight'),
      row.read<int>('sort_order'),
      configJson,
    ]);
  }

  await db.customStatement('''
CREATE TABLE ticker_tapes_new (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  ticker_type TEXT NOT NULL,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  sort_order INTEGER NOT NULL DEFAULT 0,
  config_json TEXT NOT NULL DEFAULT '{}'
)
''');
  for (final args in migrated) {
    await db.customStatement(
      'INSERT INTO ticker_tapes_new ('
      'id, label, description, ticker_type, frequency_weight, '
      'sort_order, config_json) VALUES (?, ?, ?, ?, ?, ?, ?)',
      args,
    );
  }
  await db.customStatement('DROP TABLE ticker_tapes');
  await db.customStatement(
    'ALTER TABLE ticker_tapes_new RENAME TO ticker_tapes',
  );
}

/// Moves legacy always-on image overlay KV into catalog + base curator members.
Future<void> _migrateV30ToV31StaticImageOverlayFromKv(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'config_key_values')) {
    if (await _sqliteTableExists(db, 'overlays')) {
      await ensureOverlayTypes(db);
    }
    return;
  }

  final kvRow = await db
      .customSelect(
        'SELECT value FROM config_key_values WHERE key = ?',
        variables: [Variable<String>(kLegacyDisplayImageOverlayKvKey)],
      )
      .getSingleOrNull();

  final legacy = kvRow == null
      ? null
      : parseLegacyDisplayImageOverlayKv(kvRow.read<String>('value'));

  await db.customStatement(
    'DELETE FROM config_key_values WHERE key = ?',
    <Object?>[kLegacyDisplayImageOverlayKvKey],
  );

  if (legacy == null) {
    if (await _sqliteTableExists(db, 'overlays')) {
      await ensureOverlayTypes(db);
    }
    return;
  }

  if (await _sqliteTableExists(db, 'overlays')) {
    if (!await _sqliteColumnExists(db, 'overlays', 'description')) {
      await db.customStatement(
        "ALTER TABLE overlays ADD COLUMN description TEXT NOT NULL DEFAULT ''",
      );
    }
    final existing = await db
        .customSelect(
          'SELECT id FROM overlays WHERE id = ?',
          variables: [Variable<String>(kMigratedDisplayImageOverlayId)],
        )
        .getSingleOrNull();
    if (existing == null) {
      await upsertOverlay(
        db,
        id: kMigratedDisplayImageOverlayId,
        overlayType: kOverlayTypeStaticImage,
        label: 'Display image',
        configJson: jsonEncode(legacy.toJson()),
      );
    }
  }

  if (await _sqliteTableExists(db, 'curator_configurations') &&
      await _sqliteTableExists(db, 'curator_configuration_members')) {
    final baseConfigs = await db
        .customSelect(
          "SELECT id FROM curator_configurations WHERE layer = ?",
          variables: [Variable<String>(kCuratorLayerBase)],
        )
        .get();
    for (final row in baseConfigs) {
      final configId = row.read<String>('id');
      await db.customStatement(
        'INSERT OR IGNORE INTO curator_configuration_members '
        '(configuration_id, entity_type, entity_id) VALUES (?, ?, ?)',
        <Object?>[
          configId,
          kCuratorMemberEntityOverlay,
          kMigratedDisplayImageOverlayId,
        ],
      );
    }
  }

  if (await _sqliteTableExists(db, 'overlays')) {
    await ensureOverlayTypes(db);
  }
}

/// Schema 32: derive account readiness from links + [IntegrationSecrets] via a view.
Future<void> _migrateV31ToV32IntegrationAccountsConfiguredView(
  AppDatabase db,
) async {
  await db.customStatement(kCreateIntegrationTypeRequiredAccountsTableSql);
  await seedIntegrationTypeRequiredAccounts(db);

  if (!await _sqliteTableExists(db, 'integrations')) {
    await db.customStatement(kCreateVIntegrationAccountsConfiguredViewSql);
    return;
  }

  if (await _sqliteColumnExists(db, 'integrations', 'accounts_ready')) {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      'DROP INDEX IF EXISTS idx_integrations_enabled_accounts',
    );
    await db.customStatement(
      'DROP VIEW IF EXISTS v_integration_accounts_configured',
    );
    await db.customStatement('''
CREATE TABLE integrations_new (
  id TEXT NOT NULL PRIMARY KEY,
  integration_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  config_json TEXT
)
''');
    final integrationRows = await db
        .customSelect('SELECT * FROM integrations')
        .get();
    for (final row in integrationRows) {
      await db.customStatement(
        'INSERT INTO integrations_new '
        '(id, integration_type, enabled, poll_seconds, config_json) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          row.read<String>('id'),
          row.read<String>('integration_type'),
          row.read<int>('enabled'),
          row.read<int>('poll_seconds'),
          row.read<String?>('config_json'),
        ],
      );
    }
    await db.customStatement('DROP TABLE integrations');
    await db.customStatement(
      'ALTER TABLE integrations_new RENAME TO integrations',
    );
    await db.customStatement('PRAGMA foreign_keys = ON');
  }

  await db.customStatement(kCreateVIntegrationAccountsConfiguredViewSql);
}

Future<void> _ensureIntegrationAccountsConfiguredView(AppDatabase db) async {
  final view = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'view' "
        "AND name = 'v_integration_accounts_configured' LIMIT 1",
      )
      .getSingleOrNull();
  if (view == null) {
    await db.customStatement(kCreateIntegrationTypeRequiredAccountsTableSql);
    await seedIntegrationTypeRequiredAccounts(db);
    await db.customStatement(kCreateVIntegrationAccountsConfiguredViewSql);
    return;
  }
  await seedIntegrationTypeRequiredAccounts(db);
}

/// Conservative backfill for schema 23 only (column removed in schema 32).
Future<void> _backfillIntegrationsAccountsReadyColumnsV23(
  AppDatabase db,
) async {
  if (!await _sqliteColumnExists(db, 'integrations', 'accounts_ready')) {
    return;
  }
  final rows = await db
      .customSelect('SELECT id, integration_type FROM integrations')
      .get();
  for (final row in rows) {
    final id = row.read<String>('id');
    final integrationType = row.read<String>('integration_type');
    final requires = integrationAccountTypesRequiredForIntegration(
      integrationType,
    ).isNotEmpty;
    final ready = requires ? 0 : 1;
    await db.customStatement(
      'UPDATE integrations SET accounts_ready = ? WHERE id = ?',
      [ready, id],
    );
  }
}

/// Schema 34: backfill [OverlayTypes] rows for all built-in overlay catalog entries.
Future<void> _migrateV33ToV34OverlayTypesCatalog(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'overlay_types')) {
    return;
  }
  await ensureOverlayTypes(db);
}

/// Schema 35: backfill calendar overlay types in [OverlayTypes].
Future<void> _migrateV34ToV35OverlayTypesCatalog(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'overlay_types')) {
    return;
  }
  await ensureOverlayTypes(db);
}

/// Schema 36: backfill stock quote overlay type in [OverlayTypes].
Future<void> _migrateV35ToV36OverlayTypesCatalog(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'overlay_types')) {
    return;
  }
  await ensureOverlayTypes(db);
}

/// Schema 40: backfill QR code overlay type in [OverlayTypes].
Future<void> _migrateV39ToV40QrCodeOverlayType(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'overlay_types')) {
    return;
  }
  await ensureOverlayTypes(db);
}

/// Schema 41: backfill cloud drift overlay type in [OverlayTypes].
/// Schema 42: nullable curator ticker overrides; display KV holds defaults.
Future<void> _migrateV41ToV42NullableCuratorTickerOverrides(
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
    return;
  }
  await db.customStatement(
    'DROP VIEW IF EXISTS v_integration_accounts_configured',
  );
  await db.customStatement('''
CREATE TABLE curator_configurations_new (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  layer TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  program_duration_seconds INTEGER NOT NULL DEFAULT 180,
  history_depth INTEGER NOT NULL DEFAULT 5,
  require_news_photo_for_screens INTEGER NOT NULL DEFAULT 1,
  ticker_enabled INTEGER NOT NULL DEFAULT 1,
  ticker_program_duration_seconds INTEGER,
  ticker_pixels_per_second INTEGER,
  theme_id_override TEXT,
  viewport_reserve_top_pct_override INTEGER,
  viewport_reserve_right_pct_override INTEGER,
  viewport_reserve_bottom_pct_override INTEGER,
  viewport_reserve_left_pct_override INTEGER,
  default_config INTEGER NOT NULL DEFAULT 0
);
''');
  await db.customStatement('''
INSERT INTO curator_configurations_new (
  id,
  name,
  layer,
  sort_order,
  program_duration_seconds,
  history_depth,
  require_news_photo_for_screens,
  ticker_enabled,
  ticker_program_duration_seconds,
  ticker_pixels_per_second,
  theme_id_override,
  viewport_reserve_top_pct_override,
  viewport_reserve_right_pct_override,
  viewport_reserve_bottom_pct_override,
  viewport_reserve_left_pct_override,
  default_config
)
SELECT
  id,
  name,
  layer,
  sort_order,
  program_duration_seconds,
  history_depth,
  require_news_photo_for_screens,
  COALESCE(ticker_enabled, 1),
  CASE
    WHEN ticker_program_duration_seconds = 300 THEN NULL
    ELSE ticker_program_duration_seconds
  END,
  CASE
    WHEN ticker_pixels_per_second = 80 THEN NULL
    ELSE ticker_pixels_per_second
  END,
  theme_id_override,
  viewport_reserve_top_pct_override,
  viewport_reserve_right_pct_override,
  viewport_reserve_bottom_pct_override,
  viewport_reserve_left_pct_override,
  default_config
FROM curator_configurations;
''');
  await db.customStatement('DROP TABLE curator_configurations');
  await db.customStatement(
    'ALTER TABLE curator_configurations_new RENAME TO curator_configurations',
  );
  await _ensureIntegrationAccountsConfiguredView(db);
  if (await _sqliteTableExists(db, 'config_key_values')) {
    await db.customStatement(
      "INSERT OR IGNORE INTO config_key_values (key, value) VALUES "
      "('display.ticker.program_duration_seconds', '300')",
    );
    await db.customStatement(
      "INSERT OR IGNORE INTO config_key_values (key, value) VALUES "
      "('display.ticker.pixels_per_second', '80')",
    );
  }
}

Future<void> _migrateV40ToV41CloudDriftOverlayType(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'overlay_types')) {
    return;
  }
  await ensureOverlayTypes(db);
}

/// Schema 43: default base curator + parent_configuration_id for time-slot programs.
Future<void> _migrateV42ToV43DefaultBaseCurator(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'curator_configurations')) {
    return;
  }
  await _ensureCuratorConfigurationsTickerEnabled(db);
  await _ensureCuratorConfigurationsTickerProgramDuration(db);
  await _ensureCuratorConfigurationsTickerPixelsPerSecond(db);
  if (!await _sqliteColumnExists(
    db,
    'curator_configurations',
    'parent_configuration_id',
  )) {
    await db.customStatement(
      'ALTER TABLE curator_configurations ADD COLUMN parent_configuration_id '
      'TEXT REFERENCES curator_configurations(id)',
    );
  }

  final defaultExists = await db
      .customSelect(
        'SELECT 1 FROM curator_configurations WHERE id = ? LIMIT 1',
        variables: [Variable<String>(kDefaultBaseCuratorConfigurationId)],
      )
      .getSingleOrNull();
  if (defaultExists == null) {
    await db.customStatement(
      'INSERT INTO curator_configurations ('
      'id, name, layer, sort_order, program_duration_seconds, history_depth, '
      'require_news_photo_for_screens, ticker_enabled, default_config, '
      'parent_configuration_id'
      ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)',
      <Object?>[
        kDefaultBaseCuratorConfigurationId,
        'Default',
        kCuratorLayerBase,
        5,
        180,
        5,
        1,
        1,
        0,
      ],
    );
  }

  if (await _sqliteTableExists(db, 'curator_configuration_members')) {
    for (final screenId in kDefaultBaseCuratorScreenMemberIds) {
      await db.customStatement(
        'INSERT OR IGNORE INTO curator_configuration_members '
        '(configuration_id, entity_type, entity_id) VALUES (?, ?, ?)',
        <Object?>[
          kDefaultBaseCuratorConfigurationId,
          kCuratorMemberEntityScreen,
          screenId,
        ],
      );
    }
    for (final tickerId in kDefaultBaseCuratorTickerMemberIds) {
      await db.customStatement(
        'INSERT OR IGNORE INTO curator_configuration_members '
        '(configuration_id, entity_type, entity_id) VALUES (?, ?, ?)',
        <Object?>[
          kDefaultBaseCuratorConfigurationId,
          kCuratorMemberEntityTicker,
          tickerId,
        ],
      );
    }

    for (final childId in kTimeSlotBaseCuratorConfigurationIds) {
      final childExists = await db
          .customSelect(
            'SELECT 1 FROM curator_configurations WHERE id = ? LIMIT 1',
            variables: [Variable<String>(childId)],
          )
          .getSingleOrNull();
      if (childExists == null) {
        continue;
      }
      await db.customStatement(
        'UPDATE curator_configurations SET parent_configuration_id = ? '
        'WHERE id = ?',
        <Object?>[kDefaultBaseCuratorConfigurationId, childId],
      );
      await db.customStatement(
        'DELETE FROM curator_configuration_members '
        'WHERE configuration_id = ? AND entity_type = ? AND entity_id = ?',
        <Object?>[childId, kCuratorMemberEntityScreen, 'clock_digital'],
      );
      await db.customStatement(
        'DELETE FROM curator_configuration_members '
        'WHERE configuration_id = ? AND entity_type = ? AND entity_id = ?',
        <Object?>[childId, kCuratorMemberEntityTicker, 'ticker_time'],
      );
    }
  }
}

/// Schema 44: operator-facing description on overlay catalog rows.
Future<void> _migrateV43ToV44OverlayDescription(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'overlays')) {
    return;
  }
  if (!await _sqliteColumnExists(db, 'overlays', 'description')) {
    await db.customStatement(
      "ALTER TABLE overlays ADD COLUMN description TEXT NOT NULL DEFAULT ''",
    );
  }
}

/// Schema 45: manual bucket integrations → operator manual_entry provenance.
Future<void> _migrateV44ToV45ManualEntrySource(AppDatabase db) async {
  const manualEntry = 'manual_entry';
  const bucketTypes = <String>[
    'photo_bucket',
    'video_bucket',
    'calendar_bucket',
    'joke_bucket',
    'trivia_bucket',
  ];
  const defaultBucketIds = <String>[
    'default_photo_bucket',
    'default_video_bucket',
    'default_calendar_bucket',
    'default_joke_bucket',
    'default_trivia_bucket',
  ];

  if (await _sqliteTableExists(db, 'photos')) {
    await db.customStatement(
      "UPDATE photos SET data_provider = ? WHERE data_provider = 'photo_bucket'",
      <Object?>[manualEntry],
    );
  }
  if (await _sqliteTableExists(db, 'videos')) {
    await db.customStatement(
      "UPDATE videos SET data_provider = ? WHERE data_provider = 'video_bucket'",
      <Object?>[manualEntry],
    );
  }
  if (await _sqliteTableExists(db, 'calendar_events')) {
    await db.customStatement(
      "UPDATE calendar_events SET source = ? WHERE source = 'calendar_bucket'",
      <Object?>[manualEntry],
    );
  }
  if (await _sqliteTableExists(db, 'trivia_questions')) {
    for (final id in defaultBucketIds) {
      await db.customStatement(
        'UPDATE trivia_questions SET integration_id = NULL WHERE integration_id = ?',
        <Object?>[id],
      );
    }
  }

  await db.customStatement('PRAGMA foreign_keys = OFF');
  try {
    if (await _sqliteTableExists(db, 'integration_type_required_accounts')) {
      for (final type in bucketTypes) {
        await db.customStatement(
          'DELETE FROM integration_type_required_accounts WHERE integration_type = ?',
          <Object?>[type],
        );
      }
    }
    if (await _sqliteTableExists(db, 'integrations')) {
      for (final type in bucketTypes) {
        await db.customStatement(
          'DELETE FROM integrations WHERE integration_type = ?',
          <Object?>[type],
        );
      }
    }
    if (await _sqliteTableExists(db, 'integration_types')) {
      for (final type in bucketTypes) {
        await db.customStatement(
          'DELETE FROM integration_types WHERE integration_type = ?',
          <Object?>[type],
        );
      }
    }
  } finally {
    await db.customStatement('PRAGMA foreign_keys = ON');
  }
}

/// Schema 46: Quoterism quote storage and category junction.
Future<void> _migrateV45ToV46QuoterismQuotes(AppDatabase db, Migrator m) async {
  await m.createTable(db.quoterismQuotes);
  await m.createTable(db.quoterismQuoteCategories);
}

Future<void> _migrateV46ToV47CuratorScreensEnabled(AppDatabase db) async {
  await _ensureCuratorConfigurationsScreensEnabled(db);
}

Future<void> _migrateV47ToV48ScreenConfigJson(AppDatabase db) async {
  // v48 screen config rewrite reads categories; table may not exist yet on
  // legacy snapshots (beforeOpen also ensures it, but migrations run first).
  await _ensureCuratorCategoriesTable(db);
  await migrateScreenConfigJsonV48(db);
}

/// Ensures [CuratorConfigurations.screensEnabled] is present and non-null.
Future<void> _ensureCuratorConfigurationsScreensEnabled(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'curator_configurations')) {
    return;
  }
  if (!await _sqliteColumnExists(
    db,
    'curator_configurations',
    'screens_enabled',
  )) {
    await db.customStatement(
      'ALTER TABLE curator_configurations ADD COLUMN screens_enabled '
      'INTEGER NOT NULL DEFAULT 1',
    );
  }
  await db.customStatement(
    'UPDATE curator_configurations SET screens_enabled = 1 '
    'WHERE screens_enabled IS NULL',
  );
}

/// Schema 39: trim default location catalog to five megacities; remove retired rows.
Future<void> _migrateV38ToV39TrimLocationCatalog(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'interests_locations')) {
    return;
  }
  await ensureDefaultInterestsLocations(db);
  const fallbackLocationId = 'new_york_ny';
  for (final id in kRetiredDefaultWeatherLocationCatalogIds) {
    if (await _sqliteTableExists(db, 'weather_alerts')) {
      await db.customStatement(
        'DELETE FROM weather_alerts WHERE location_id = ?',
        [id],
      );
    }
    if (await _sqliteTableExists(db, 'weather_current')) {
      await db.customStatement(
        'DELETE FROM weather_current WHERE location_id = ?',
        [id],
      );
    }
    await db.customStatement('DELETE FROM interests_locations WHERE id = ?', [
      id,
    ]);
  }
  if (await _sqliteTableExists(db, 'screens')) {
    final rows = await db
        .customSelect('SELECT id, config_json FROM screens')
        .get();
    for (final row in rows) {
      final configJson = row.read<String?>('config_json');
      if (configJson == null || configJson.isEmpty) continue;
      try {
        final decoded = jsonDecode(configJson);
        if (decoded is! Map<String, dynamic>) continue;
        final locationId = decoded['locationId'];
        if (locationId is! String ||
            !kRetiredDefaultWeatherLocationCatalogIds.contains(locationId)) {
          continue;
        }
        decoded['locationId'] = fallbackLocationId;
        final updated = jsonEncode(decoded);
        await db.customStatement(
          'UPDATE screens SET config_json = ? WHERE id = ?',
          [updated, row.read<String>('id')],
        );
      } catch (_) {
        // Leave malformed config_json unchanged.
      }
    }
  }
}

/// Schema 37: backfill photo slideshow overlay type in [OverlayTypes].
/// Adds [photo_categories] / [video_categories] and backfills from legacy columns.
Future<void> _migrateV37ToV38PhotoVideoCategories(
  AppDatabase db,
  Migrator m,
) async {
  await _ensureCuratorCategoriesTable(db, migrator: m);
  await m.createTable(db.photoCategories);
  await m.createTable(db.videoCategories);
  if (!await _sqliteTableExists(db, 'curator_categories')) {
    return;
  }
  if (await _sqliteTableExists(db, 'photos')) {
    await db.customStatement('''
INSERT OR IGNORE INTO photo_categories (photo_id, category_id)
SELECT p.id, p.category FROM photos p
WHERE p.category IS NOT NULL AND p.category != ''
  AND EXISTS (
    SELECT 1 FROM curator_categories c WHERE c.id = p.category
  )
''');
  }
  if (await _sqliteTableExists(db, 'videos')) {
    await db.customStatement('''
INSERT OR IGNORE INTO video_categories (video_id, category_id)
SELECT v.id, v.category FROM videos v
WHERE v.category IS NOT NULL AND v.category != ''
  AND EXISTS (
    SELECT 1 FROM curator_categories c WHERE c.id = v.category
  )
''');
  }
}

Future<void> _migrateV36ToV37OverlayTypesCatalog(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'overlay_types')) {
    return;
  }
  await ensureOverlayTypes(db);
}

/// Schema 33: per-curator viewport edge reserve overrides (nullable percent).
Future<void> _migrateV32ToV33ViewportReserveOverrides(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'curator_configurations')) {
    return;
  }
  const columns = <String>[
    'viewport_reserve_top_pct_override',
    'viewport_reserve_right_pct_override',
    'viewport_reserve_bottom_pct_override',
    'viewport_reserve_left_pct_override',
  ];
  for (final column in columns) {
    if (!await _sqliteColumnExists(db, 'curator_configurations', column)) {
      await db.customStatement(
        'ALTER TABLE curator_configurations ADD COLUMN $column INTEGER',
      );
    }
  }
}

/// Schema 49: generic task board lists and tasks for integration collectors.
Future<void> _migrateV48ToV49TaskTables(AppDatabase db, Migrator m) async {
  await m.createTable(db.taskLists);
  await m.createTable(db.tasks);
}

/// Category slugs for legacy stock symbol ids (matches initial seed mapping).
const _kStockSymbolCategoryBackfill = <String, String>{
  'aapl': 'technology',
  'msft': 'technology',
  'goog': 'technology',
  'nvda': 'technology',
  'meta': 'technology',
  'intc': 'technology',
  'csco': 'technology',
  'orcl': 'technology',
  'ibm': 'technology',
  'amzn': 'technology',
  'jpm': 'finance',
  'v': 'finance',
  'ma': 'finance',
  'spy': 'finance',
  'voo': 'finance',
  'qqq': 'finance',
  'iwm': 'finance',
  'nflx': 'entertainment',
  'dis': 'entertainment',
  'tsla': 'automotive',
  'jnj': 'health',
  'unh': 'health',
  'xom': 'general',
  'wmt': 'general',
  'ko': 'general',
};

Future<void> _migrateV49ToV50StockSymbolCategories(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'interests_stock_symbols')) {
    return;
  }
  if (!await _sqliteColumnExists(db, 'interests_stock_symbols', 'category')) {
    await db.customStatement(
      "ALTER TABLE interests_stock_symbols ADD COLUMN category TEXT NOT NULL DEFAULT 'general'",
    );
  }
  for (final entry in _kStockSymbolCategoryBackfill.entries) {
    await db.customStatement(
      'UPDATE interests_stock_symbols SET category = ? WHERE id = ?',
      [entry.value, entry.key],
    );
  }
  await _backfillNullInterestsStockSymbolCategories(db);
}

/// Schema 51: repair rows where [InterestsStockSymbols.category] was left NULL
/// (e.g. nullable column add or upsert without category before defaults applied).
Future<void> _migrateV50ToV51InterestsStockSymbolCategoryBackfill(
  AppDatabase db,
) async {
  await _backfillNullInterestsStockSymbolCategories(db);
}

Future<void> _ensureInterestsStockSymbolCategoriesPopulated(
  AppDatabase db,
) async {
  await _backfillNullInterestsStockSymbolCategories(db);
}

Future<void> _backfillNullInterestsStockSymbolCategories(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'interests_stock_symbols')) {
    return;
  }
  if (!await _sqliteColumnExists(db, 'interests_stock_symbols', 'category')) {
    return;
  }
  await db.customStatement(
    "UPDATE interests_stock_symbols "
    "SET category = 'general' "
    "WHERE category IS NULL OR trim(category) = ''",
  );
}

/// Schema 52: curator member add/remove ops, screen require_news_photo, sort rebalance,
/// weekday/weekend enhancement curators.
Future<void> _migrateV51ToV52CuratorMemberOpsAndSortRebalance(
  AppDatabase db,
) async {
  if (await _sqliteTableExists(db, 'curator_configuration_members')) {
    if (!await _sqliteColumnExists(
      db,
      'curator_configuration_members',
      'op',
    )) {
      await db.customStatement(
        "ALTER TABLE curator_configuration_members ADD COLUMN op "
        "TEXT NOT NULL DEFAULT '${kCuratorMemberOpAdd}'",
      );
    }
    await db.customStatement(
      "UPDATE curator_configuration_members SET op = '${kCuratorMemberOpAdd}' "
      "WHERE op IS NULL OR trim(op) = ''",
    );
  }

  if (await _sqliteTableExists(db, 'screens')) {
    if (!await _sqliteColumnExists(db, 'screens', 'require_news_photo')) {
      await db.customStatement(
        'ALTER TABLE screens ADD COLUMN require_news_photo '
        'INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (await _sqliteTableExists(db, 'curator_configurations') &&
        await _sqliteTableExists(db, 'curator_configuration_members')) {
      final newsTypes = kNewsScreenTypesRequiringPhoto.map((t) => "'$t'").join(
        ', ',
      );
      await db.customStatement('''
UPDATE screens SET require_news_photo = 0
WHERE screen_type IN ($newsTypes)
AND id IN (
  SELECT DISTINCT m.entity_id
  FROM curator_configuration_members m
  INNER JOIN curator_configurations c ON c.id = m.configuration_id
  WHERE m.entity_type = '${kCuratorMemberEntityScreen}'
    AND c.require_news_photo_for_screens = 0
)
''');
    }
  }

  if (await _sqliteTableExists(db, 'curator_configurations')) {
    await db.customStatement(
      'UPDATE curator_configurations SET sort_order = sort_order + 100 '
      'WHERE sort_order >= 100 AND sort_order <= 199',
    );
    await db.customStatement(
      'UPDATE curator_configurations SET sort_order = sort_order + 90 '
      'WHERE sort_order >= 10 AND sort_order <= 99',
    );
  }

  await _ensureWeekdayWeekendCuratorConfigurationsV52(db);
}

const int _kWeekdayDaysMask = 0x1F;
const int _kWeekendDaysMask = 0x60;

Future<void> _ensureWeekdayWeekendCuratorConfigurationsV52(AppDatabase db) async {
  if (!await _sqliteTableExists(db, 'curator_configurations')) {
    return;
  }
  final weekdayExists = await db
      .customSelect(
        "SELECT 1 FROM curator_configurations WHERE id = 'weekday' LIMIT 1",
      )
      .getSingleOrNull();
  if (weekdayExists == null) {
    await db.customStatement(
      'INSERT INTO curator_configurations ('
      'id, name, layer, sort_order, program_duration_seconds, history_depth, '
      'require_news_photo_for_screens, screens_enabled, ticker_enabled, default_config'
      ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        'weekday',
        'Weekdays',
        kCuratorLayerEnhancement,
        10,
        180,
        5,
        1,
        1,
        1,
        0,
      ],
    );
    await db.customStatement(
      'INSERT INTO curator_schedule_rules '
      '(id, configuration_id, priority, days_of_week_mask, repeat_annually) '
      'VALUES (?, ?, ?, ?, 1)',
      <Object?>['weekday_days', 'weekday', 10, _kWeekdayDaysMask],
    );
    for (final screenId in [
      'photo',
      'photo_collage_nine_square',
      'video',
    ]) {
      await db.customStatement(
        'INSERT OR IGNORE INTO curator_configuration_members '
        '(configuration_id, entity_type, entity_id, op) VALUES (?, ?, ?, ?)',
        <Object?>[
          'weekday',
          kCuratorMemberEntityScreen,
          screenId,
          kCuratorMemberOpRemove,
        ],
      );
    }
  }

  final weekendExists = await db
      .customSelect(
        "SELECT 1 FROM curator_configurations WHERE id = 'weekend' LIMIT 1",
      )
      .getSingleOrNull();
  if (weekendExists == null) {
    await db.customStatement(
      'INSERT INTO curator_configurations ('
      'id, name, layer, sort_order, program_duration_seconds, history_depth, '
      'require_news_photo_for_screens, screens_enabled, ticker_enabled, default_config'
      ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        'weekend',
        'Weekend',
        kCuratorLayerEnhancement,
        10,
        180,
        5,
        1,
        1,
        1,
        0,
      ],
    );
    await db.customStatement(
      'INSERT INTO curator_schedule_rules '
      '(id, configuration_id, priority, days_of_week_mask, repeat_annually) '
      'VALUES (?, ?, ?, ?, 1)',
      <Object?>['weekend_days', 'weekend', 10, _kWeekendDaysMask],
    );
    for (final screenId in [
      'photo',
      'photo_collage_nine_square',
      'video',
      'jokes',
      'trivia',
    ]) {
      await db.customStatement(
        'INSERT OR IGNORE INTO curator_configuration_members '
        '(configuration_id, entity_type, entity_id, op) VALUES (?, ?, ?, ?)',
        <Object?>[
          'weekend',
          kCuratorMemberEntityScreen,
          screenId,
          kCuratorMemberOpAdd,
        ],
      );
    }
    for (final screenId in ['stock_quotes', 'news_columns', 'calendar']) {
      await db.customStatement(
        'INSERT OR IGNORE INTO curator_configuration_members '
        '(configuration_id, entity_type, entity_id, op) VALUES (?, ?, ?, ?)',
        <Object?>[
          'weekend',
          kCuratorMemberEntityScreen,
          screenId,
          kCuratorMemberOpRemove,
        ],
      );
    }
    await db.customStatement(
      'INSERT OR IGNORE INTO curator_configuration_members '
      '(configuration_id, entity_type, entity_id, op) VALUES (?, ?, ?, ?)',
      <Object?>[
        'weekend',
        kCuratorMemberEntityTicker,
        'ticker_custom',
        kCuratorMemberOpAdd,
      ],
    );
    await db.customStatement(
      'INSERT OR IGNORE INTO curator_configuration_members '
      '(configuration_id, entity_type, entity_id, op) VALUES (?, ?, ?, ?)',
      <Object?>[
        'weekend',
        kCuratorMemberEntityTicker,
        'ticker_stocks',
        kCuratorMemberOpRemove,
      ],
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
