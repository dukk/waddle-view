import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../layout/screen_layout_parse.dart';
import 'config_json_documentation.dart';
import 'content_category_defaults.dart';
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
    CuratorDataKeyProgramLimits,
    RssFeedSources,
    RssArticles,
    JokeCategories,
    Jokes,
    JokeGenerationBatches,
    TriviaCategories,
    TriviaQuestions,
    TriviaGenerationBatches,
    CalendarEvents,
    WeatherLocations,
    WeatherCurrent,
    WeatherAlerts,
    Photos,
    Videos,
    PexelsFetchBatches,
    StockSymbols,
    StockQuotes,
    RejectTerms,
    Users,
    UserSessions,
    UserOauthIdentities,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 46;

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
      if (from < 40) {
        final legacyTicker = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'ticker_definitions';",
        ).get();
        if (legacyTicker.isNotEmpty) {
          await customStatement(
            'ALTER TABLE ticker_definitions RENAME TO ticker_tapes;',
          );
        }
      }
      if (from < 6) {
        await customStatement('DROP TABLE IF EXISTS ticker_conditions;');
        await customStatement('DROP TABLE IF EXISTS ticker_condition_groups;');
        await customStatement('DROP TABLE IF EXISTS ticker_screen_runtimes;');
        await customStatement('DROP TABLE IF EXISTS ticker_screens;');
        await customStatement('DROP TABLE IF EXISTS ticker_curated_items;');
      }
      if (from < 3) {
        await m.createTable(rssFeedSources);
        await m.createTable(rssArticles);
      }
      if (from < 6) {
        await m.createTable(screens);
        await customStatement('''
CREATE TABLE IF NOT EXISTS curator_settings (
  id TEXT NOT NULL PRIMARY KEY,
  program_duration_ms INTEGER NOT NULL DEFAULT 180000,
  history_depth INTEGER NOT NULL DEFAULT 5
);
''');
      }
      if (from < 7) {
        await m.createTable(jokeCategories);
        await m.createTable(jokes);
      }
      if (from < 8) {
        await customStatement(
          'ALTER TABLE joke_categories ADD COLUMN min_jokes INTEGER NOT NULL DEFAULT 10',
        );
        await customStatement(
          'ALTER TABLE joke_categories ADD COLUMN max_jokes INTEGER NOT NULL DEFAULT 100',
        );
        await m.createTable(jokeGenerationBatches);
      }
      if (from < 9) {
        await m.createTable(calendarEvents);
      }
      if (from < 10) {
        await m.createTable(triviaCategories);
        await m.createTable(triviaQuestions);
        await m.createTable(triviaGenerationBatches);
      }
      if (from < 11) {
        await m.createTable(curatorDataKeyProgramLimits);
        await customStatement(
          'ALTER TABLE screen_definitions ADD COLUMN min_placements_per_program INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE screen_definitions ADD COLUMN max_placements_per_program INTEGER NULL',
        );
        await customStatement(
          'ALTER TABLE screen_definitions ADD COLUMN data_key TEXT NOT NULL DEFAULT \'\'',
        );
      }
      if (from < 12) {
        await m.createTable(weatherLocations);
        await m.createTable(weatherCurrent);
      }
      if (from < 14) {
        await customStatement(
          'ALTER TABLE screen_definitions RENAME COLUMN dwell_ms TO dwell_seconds;',
        );
        await customStatement(
          'ALTER TABLE screen_definitions RENAME COLUMN min_gap_between_shows_ms TO min_gap_between_shows_seconds;',
        );
        await customStatement(
          'ALTER TABLE curator_settings RENAME COLUMN program_duration_ms TO program_duration_seconds;',
        );
        await customStatement(
          'UPDATE screen_definitions SET dwell_seconds = CASE '
          'WHEN dwell_seconds <= 0 THEN 1 '
          'ELSE CAST((dwell_seconds + 999) / 1000 AS INTEGER) END;',
        );
        await customStatement(
          'UPDATE screen_definitions SET min_gap_between_shows_seconds = CASE '
          'WHEN min_gap_between_shows_seconds <= 0 THEN 0 '
          'ELSE CAST((min_gap_between_shows_seconds + 999) / 1000 AS INTEGER) END;',
        );
        await customStatement(
          'UPDATE curator_settings SET program_duration_seconds = CASE '
          'WHEN program_duration_seconds <= 0 THEN 1 '
          'ELSE CAST((program_duration_seconds + 999) / 1000 AS INTEGER) END;',
        );
      }
      if (from < 15) {
        await customStatement(
          'DROP INDEX IF EXISTS idx_category_icons_blob_key;',
        );
        await customStatement('DROP TABLE IF EXISTS category_icons;');
      }
      if (from < 16) {
        await customStatement('''
INSERT OR REPLACE INTO dashboard_kv (key, value)
SELECT '$kCuratorProgramDurationSecondsKvKey', CAST(program_duration_seconds AS TEXT)
FROM curator_settings WHERE id = 'app';
''');
        await customStatement('''
INSERT OR REPLACE INTO dashboard_kv (key, value)
SELECT '$kCuratorHistoryDepthKvKey', CAST(history_depth AS TEXT)
FROM curator_settings WHERE id = 'app';
''');
        await customStatement('DROP TABLE IF EXISTS curator_settings;');
        await customStatement(
          'ALTER TABLE dashboard_kv RENAME TO config_key_values;',
        );
      }
      if (from < 17) {
        await m.createTable(photos);
        await m.createTable(videos);
        await m.createTable(pexelsFetchBatches);
      }
      if (from < 18) {
        final legacyTables = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name IN ('pexels_photos','pexels_videos')",
        ).get();
        final legacy = legacyTables.map((r) => r.read<String>('name')).toSet();
        if (legacy.contains('pexels_photos')) {
          await customStatement('ALTER TABLE pexels_photos RENAME TO photos;');
          await customStatement(
            "ALTER TABLE photos ADD COLUMN data_provider TEXT NOT NULL DEFAULT '$kMediaDataProviderPexels';",
          );
          await customStatement(
            'DROP INDEX IF EXISTS idx_pexels_photos_fetched;',
          );
          await customStatement(
            'DROP INDEX IF EXISTS idx_pexels_photos_category;',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_photos_fetched ON photos (fetched_at_ms);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_photos_category ON photos (category);',
          );
        }
        if (legacy.contains('pexels_videos')) {
          await customStatement('ALTER TABLE pexels_videos RENAME TO videos;');
          await customStatement(
            "ALTER TABLE videos ADD COLUMN data_provider TEXT NOT NULL DEFAULT '$kMediaDataProviderPexels';",
          );
          await customStatement(
            'DROP INDEX IF EXISTS idx_pexels_videos_fetched;',
          );
          await customStatement(
            'DROP INDEX IF EXISTS idx_pexels_videos_category;',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_videos_fetched ON videos (fetched_at_ms);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_videos_category ON videos (category);',
          );
        }
      }
      if (from < 19) {
        await m.createTable(contentCategories);
        for (final d in kContentCategoryDefaults) {
          await into(contentCategories).insert(
            ContentCategoriesCompanion.insert(
              id: d.id,
              label: d.label,
              iconBlobKey: d.iconBlobKey == null
                  ? const Value.absent()
                  : Value(d.iconBlobKey),
              materialIconName: d.materialIconName == null
                  ? const Value.absent()
                  : Value(d.materialIconName),
            ),
          );
        }
      }
      if (from < 20) {
        Future<bool> legacyTableExists(String table) async {
          final rows = await customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = '$table';",
          ).get();
          return rows.isNotEmpty;
        }

        Future<Set<String>> legacyColumnNames(String table) async {
          final rows = await customSelect('PRAGMA table_info($table);').get();
          return rows.map((r) => r.read<String>('name')).toSet();
        }

        if (await legacyTableExists('provider_settings')) {
          var cols = await legacyColumnNames('provider_settings');
          if (cols.contains('extra_json')) {
            await customStatement(
              'ALTER TABLE provider_settings RENAME COLUMN extra_json TO config_json;',
            );
            cols = await legacyColumnNames('provider_settings');
          }
          if (!cols.contains('config_json_schema')) {
            await customStatement(
              'ALTER TABLE provider_settings ADD COLUMN config_json_schema TEXT;',
            );
          }
          if (!cols.contains('example_config_json')) {
            await customStatement(
              'ALTER TABLE provider_settings ADD COLUMN example_config_json TEXT;',
            );
          }
          final providerRows = await customSelect(
            'SELECT id, provider_type FROM provider_settings;',
          ).get();
          for (final p in providerRows) {
            final id = p.read<String>('id');
            final providerType = p.read<String>('provider_type');
            final doc = providerConfigJsonDocForType(providerType);
            await customStatement(
              'UPDATE provider_settings SET config_json_schema = ?, '
              'example_config_json = ? WHERE id = ?',
              <Object?>[doc.schema, doc.example, id],
            );
          }
        }

        if (await legacyTableExists('screen_definitions')) {
          var cols = await legacyColumnNames('screen_definitions');
          if (!cols.contains('layout_json_schema')) {
            await customStatement(
              'ALTER TABLE screen_definitions ADD COLUMN layout_json_schema TEXT;',
            );
          }
          if (!cols.contains('example_layout_json')) {
            await customStatement(
              'ALTER TABLE screen_definitions ADD COLUMN example_layout_json TEXT;',
            );
          }
          final screenRows = await customSelect(
            'SELECT id FROM screen_definitions',
          ).get();
          for (final s in screenRows) {
            final id = s.read<String>('id');
            await customStatement(
              'UPDATE screen_definitions SET layout_json_schema = ?, '
              'example_layout_json = ? WHERE id = ?',
              <Object?>[
                kMigration20ScreenLayoutJsonSchema,
                kMigration20ExampleScreenLayoutJson,
                id,
              ],
            );
          }
        }
      }
      if (from < 21) {
        await m.createTable(stockSymbols);
        await m.createTable(stockQuotes);
      }
      if (from < 22) {
        await customStatement(
          'ALTER TABLE calendar_events ADD COLUMN ical_uid TEXT;',
        );
        await customStatement(
          'ALTER TABLE calendar_events ADD COLUMN category_id TEXT '
          'REFERENCES content_categories (id);',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_calendar_events_ical_uid '
          'ON calendar_events (ical_uid);',
        );
      }
      if (from < 23) {
        await m.createTable(tickerTapes);
      }
      if (from < 24) {
        await customStatement(
          'ALTER TABLE blob_metadata ADD COLUMN pixel_width INTEGER;',
        );
        await customStatement(
          'ALTER TABLE blob_metadata ADD COLUMN pixel_height INTEGER;',
        );
      }
      if (from < 25) {
        await m.createTable(weatherAlerts);
      }
      if (from < 26) {
        Future<bool> legacyTableExists(String table) async {
          // Table name inputs here come from hard-coded strings in this
          // migration, so string interpolation is safe.
          final rows = await customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = '$table';",
          ).get();
          return rows.isNotEmpty;
        }

        Future<Set<String>> legacyColumnNames(String table) async {
          final rows = await customSelect('PRAGMA table_info($table);').get();
          return rows.map((r) => r.read<String>('name')).toSet();
        }

        Future<void> ensureSuppressedColumn(String table) async {
          if (!await legacyTableExists(table)) {
            return;
          }
          final cols = await legacyColumnNames(table);
          if (cols.contains('suppressed')) {
            return;
          }
          await customStatement(
            'ALTER TABLE $table ADD COLUMN suppressed INTEGER '
            'NOT NULL DEFAULT 0',
          );
        }

        await ensureSuppressedColumn('jokes');
        await ensureSuppressedColumn('rss_articles');
        await ensureSuppressedColumn('trivia_questions');
        await ensureSuppressedColumn('photos');
        await ensureSuppressedColumn('videos');
      }
      if (from < 27) {
        await transaction(() async {
          final rows = await customSelect(
            'SELECT id, name, description, enabled, layout_json, dwell_seconds, '
            'frequency_weight, min_gap_between_shows_seconds, '
            'min_placements_per_program, max_placements_per_program, data_key '
            'FROM screen_definitions',
          ).get();
          await customStatement(
            'ALTER TABLE screen_definitions RENAME TO screen_definitions_pre_v27;',
          );
          await m.createTable(screens);
          for (final r in rows) {
            final layoutJson = r.read<String>('layout_json');
            final extracted = extractLegacyScreenFields(layoutJson);
            final doc = screenConfigJsonDocForType(extracted.screenType);
            final enabledRaw = r.data['enabled'];
            final enabled = enabledRaw is bool
                ? enabledRaw
                : ((enabledRaw as int) != 0);
            final maxRaw = r.data['max_placements_per_program'];
            await into(screens).insert(
              ScreensCompanion.insert(
                id: r.read<String>('id'),
                name: r.read<String>('name'),
                description: Value(r.read<String>('description')),
                enabled: Value(enabled),
                screenType: extracted.screenType,
                configJson: Value(extracted.configJson),
                configJsonSchema: Value(doc.schema),
                exampleConfigJson: Value(doc.example),
                dwellSeconds: Value(r.read<int>('dwell_seconds')),
                frequencyWeight: Value(r.read<int>('frequency_weight')),
                minGapBetweenShowsSeconds: Value(
                  r.read<int>('min_gap_between_shows_seconds'),
                ),
                minPlacementsPerProgram: Value(
                  r.read<int>('min_placements_per_program'),
                ),
                maxPlacementsPerProgram: maxRaw == null
                    ? const Value.absent()
                    : Value(r.read<int>('max_placements_per_program')),
                dataKey: Value(r.read<String>('data_key')),
              ),
            );
          }
          await customStatement('DROP TABLE screen_definitions_pre_v27;');
        });
      }
      if (from < 28) {
        await customStatement(kLegacyEnsureDisplayOverlaySchedulesTableSql);
      }
      if (from < 29) {
        final wlTables = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'weather_locations';",
        ).get();
        if (wlTables.isNotEmpty) {
          final wlCols = await customSelect(
            'PRAGMA table_info(weather_locations);',
          ).get();
          final wlNames = wlCols.map((r) => r.read<String>('name')).toSet();
          if (!wlNames.contains('include_active_weather_alerts')) {
            await customStatement(
              'ALTER TABLE weather_locations ADD COLUMN include_active_weather_alerts '
              'INTEGER NOT NULL DEFAULT 1',
            );
          }
        }
      }
      if (from < 30) {
        final rssTables = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'rss_feed_sources';",
        ).get();
        if (rssTables.isNotEmpty) {
          final rssCols = await customSelect(
            'PRAGMA table_info(rss_feed_sources);',
          ).get();
          final rssNames = rssCols.map((r) => r.read<String>('name')).toSet();
          if (!rssNames.contains('consecutive_failures')) {
            await customStatement(
              'ALTER TABLE rss_feed_sources ADD COLUMN consecutive_failures '
              'INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (!rssNames.contains('next_retry_at')) {
            await customStatement(
              'ALTER TABLE rss_feed_sources ADD COLUMN next_retry_at INTEGER',
            );
          }
        }
      }
      if (from < 31) {
        await m.createTable(rejectTerms);
        await _seedDefaultRejectTerms(this);
      }
      if (from < 32) {
        final overlayTables = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'display_overlay_schedules';",
        ).get();
        if (overlayTables.isNotEmpty) {
          final cols = await customSelect(
            'PRAGMA table_info(display_overlay_schedules);',
          ).get();
          final names = cols.map((r) => r.read<String>('name')).toSet();
          if (!names.contains('settings_json') && !names.contains('config_json')) {
            await customStatement(
              'ALTER TABLE display_overlay_schedules ADD COLUMN settings_json '
              "TEXT NOT NULL DEFAULT '{}'",
            );
          }
        }
      }
      if (from < 33) {
        Future<bool> legacyTableExists(String table) async {
          final rows = await customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = '$table';",
          ).get();
          return rows.isNotEmpty;
        }

        Future<Set<String>> tableColumnNames(String table) async {
          final rows = await customSelect('PRAGMA table_info($table);').get();
          return rows.map((r) => r.read<String>('name')).toSet();
        }

        if (await legacyTableExists('ticker_tapes')) {
          final tCols = await tableColumnNames('ticker_tapes');
          if (!tCols.contains('config_json_schema')) {
            await customStatement(
              'ALTER TABLE ticker_tapes ADD COLUMN config_json_schema TEXT;',
            );
          }
          if (!tCols.contains('example_config_json')) {
            await customStatement(
              'ALTER TABLE ticker_tapes ADD COLUMN example_config_json TEXT;',
            );
          }
        }

        Future<String?> screenTableForV33() async {
          if (await legacyTableExists('screens')) {
            return 'screens';
          }
          if (await legacyTableExists('screen_definitions')) {
            return 'screen_definitions';
          }
          return null;
        }

        final screenTable = await screenTableForV33();
        if (screenTable != null) {
          final screenCols = await tableColumnNames(screenTable);
          if (screenCols.contains('screen_type')) {
            final screenRows = await customSelect(
              'SELECT id, screen_type FROM $screenTable;',
            ).get();
            for (final s in screenRows) {
              final id = s.read<String>('id');
              final screenType = s.read<String>('screen_type');
              final doc = screenConfigJsonDocForType(screenType);
              await customStatement(
                'UPDATE $screenTable SET config_json_schema = ?, '
                'example_config_json = ? WHERE id = ?',
                <Object?>[doc.schema, doc.example, id],
              );
            }
          }
        }

        if (await legacyTableExists('provider_settings')) {
          final providerRows = await customSelect(
            'SELECT id, provider_type FROM provider_settings;',
          ).get();
          for (final p in providerRows) {
            final id = p.read<String>('id');
            final providerType = p.read<String>('provider_type');
            final doc = providerConfigJsonDocForType(providerType);
            await customStatement(
              'UPDATE provider_settings SET config_json_schema = ?, '
              'example_config_json = ? WHERE id = ?',
              <Object?>[doc.schema, doc.example, id],
            );
          }
        }

        if (await legacyTableExists('ticker_tapes')) {
          final tickerRows = await select(tickerTapes).get();
          for (final tk in tickerRows) {
            final doc = tickerSlotConfigJsonDocForType(tk.tickerType);
            await (update(
              tickerTapes,
            )..where((r) => r.id.equals(tk.id))).write(
              TickerTapesCompanion(
                configJsonSchema: Value(doc.schema),
                exampleConfigJson: Value(doc.example),
              ),
            );
          }
        }
      }
      if (from < 34) {
        Future<bool> legacyOverlayTableExists() async {
          final rows = await customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'display_overlay_schedules';",
          ).get();
          return rows.isNotEmpty;
        }

        Future<Set<String>> overlayColumnNames() async {
          final rows = await customSelect(
            'PRAGMA table_info(display_overlay_schedules);',
          ).get();
          return rows.map((r) => r.read<String>('name')).toSet();
        }

        if (await legacyOverlayTableExists()) {
          var names = await overlayColumnNames();
          if (names.contains('settings_json')) {
            await customStatement(
              'ALTER TABLE display_overlay_schedules RENAME COLUMN settings_json TO config_json',
            );
            names = await overlayColumnNames();
          }
          if (!names.contains('config_json')) {
            await customStatement(
              'ALTER TABLE display_overlay_schedules ADD COLUMN config_json '
              "TEXT NOT NULL DEFAULT '{}'",
            );
            names = await overlayColumnNames();
          }
          if (!names.contains('config_json_schema')) {
            await customStatement(
              'ALTER TABLE display_overlay_schedules ADD COLUMN config_json_schema TEXT;',
            );
          }
          if (!names.contains('example_config_json')) {
            await customStatement(
              'ALTER TABLE display_overlay_schedules ADD COLUMN example_config_json TEXT;',
            );
          }
          final heartsDoc = displayOverlayConfigJsonDocForType(
            kOverlayTypeHeartsRain,
          );
          final confettiDoc = displayOverlayConfigJsonDocForType(
            kOverlayTypeBirthdayConfetti,
          );
          await customStatement(
            'UPDATE display_overlay_schedules SET config_json_schema = ?, '
            'example_config_json = ? WHERE overlay_kind = ?',
            <Object?>[heartsDoc.schema, heartsDoc.example, kOverlayTypeHeartsRain],
          );
          await customStatement(
            'UPDATE display_overlay_schedules SET config_json_schema = ?, '
            'example_config_json = ? WHERE overlay_kind = ?',
            <Object?>[confettiDoc.schema, confettiDoc.example, kOverlayTypeBirthdayConfetti],
          );
        }
      }
      if (from < 36) {
        Future<bool> v36TableExists(String table) async {
          final rows = await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';",
          ).get();
          return rows.isNotEmpty;
        }
        if (await v36TableExists('provider_settings')) {
          await customStatement(
            "UPDATE provider_settings SET id = 'news_rss', provider_type = 'news_rss' "
            "WHERE id = 'rss';",
          );
          await customStatement(
            "UPDATE provider_settings SET id = 'joke_openai', provider_type = 'joke_openai' "
            "WHERE id = 'jokes';",
          );
          await customStatement(
            "UPDATE provider_settings SET id = 'trivia_openai', provider_type = 'trivia_openai' "
            "WHERE id = 'trivia';",
          );
          await customStatement(
            "UPDATE provider_settings SET id = 'trivia_opentdb', provider_type = 'trivia_opentdb' "
            "WHERE id = 'opentdb_trivia';",
          );
          await customStatement(
            "UPDATE provider_settings SET id = 'weather_openweathermap', "
            "provider_type = 'weather_openweathermap' WHERE id = 'weather';",
          );
          await customStatement(
            "UPDATE provider_settings SET id = 'weather_nws_alerts', "
            "provider_type = 'weather_nws_alerts' WHERE id = 'nws_weather_alerts';",
          );
          await customStatement(
            "UPDATE provider_settings SET id = 'calendar_google', "
            "provider_type = 'calendar_google' WHERE id = 'google_calendar';",
          );
          await customStatement(
            "UPDATE provider_settings SET id = 'calendar_outlook', "
            "provider_type = 'calendar_outlook' WHERE id = 'outlook_calendar';",
          );
          await customStatement(
            "UPDATE provider_settings SET id = 'media_onedrive', "
            "provider_type = 'media_onedrive' WHERE id = 'onedrive_media';",
          );
          await customStatement(
            "UPDATE provider_settings SET id = 'media_flickr', "
            "provider_type = 'media_flickr' WHERE id = 'flickr_media';",
          );
          await customStatement(
            "UPDATE provider_settings SET id = 'media_bing_iotd', "
            "provider_type = 'media_bing_iotd' WHERE id = 'bing_iotd';",
          );
          await customStatement(
            "UPDATE provider_settings SET id = 'media_pexels', "
            "provider_type = 'media_pexels' WHERE id = 'pexels';",
          );
          await customStatement(
            "UPDATE provider_settings SET id = 'stock_finnhub', "
            "provider_type = 'stock_finnhub' WHERE id = 'stocks';",
          );
        }
        if (await v36TableExists('photos')) {
          await customStatement(
            "UPDATE photos SET data_provider = 'media_pexels' WHERE data_provider = 'pexels';",
          );
          await customStatement(
            "UPDATE photos SET data_provider = 'media_onedrive' "
            "WHERE data_provider = 'onedrive_media';",
          );
          await customStatement(
            "UPDATE photos SET data_provider = 'media_flickr' WHERE data_provider = 'flickr_media';",
          );
          await customStatement(
            "UPDATE photos SET data_provider = 'media_bing_iotd' WHERE data_provider = 'bing_iotd';",
          );
        }
        if (await v36TableExists('videos')) {
          await customStatement(
            "UPDATE videos SET data_provider = 'media_pexels' WHERE data_provider = 'pexels';",
          );
          await customStatement(
            "UPDATE videos SET data_provider = 'media_onedrive' "
            "WHERE data_provider = 'onedrive_media';",
          );
        }
        if (await v36TableExists('config_key_values')) {
          await customStatement(
            "UPDATE config_key_values SET key = replace(key, 'provider.pexels.', "
            "'provider.media_pexels.') WHERE key LIKE 'provider.pexels.%';",
          );
          await customStatement(
            "UPDATE config_key_values SET key = replace(key, 'provider.flickr_media.', "
            "'provider.media_flickr.') WHERE key LIKE 'provider.flickr_media.%';",
          );
          await customStatement(
            "UPDATE config_key_values SET key = replace(key, 'provider.bing_iotd.', "
            "'provider.media_bing_iotd.') WHERE key LIKE 'provider.bing_iotd.%';",
          );
          await customStatement(
            "UPDATE config_key_values SET key = replace(key, 'provider.stocks.', "
            "'provider.stock_finnhub.') WHERE key LIKE 'provider.stocks.%';",
          );
          await customStatement(
            "UPDATE config_key_values SET key = replace(key, 'provider.google_calendar.', "
            "'provider.calendar_google.') WHERE key LIKE 'provider.google_calendar.%';",
          );
          await customStatement(
            "UPDATE config_key_values SET key = replace(key, 'provider.outlook_calendar.', "
            "'provider.calendar_outlook.') WHERE key LIKE 'provider.outlook_calendar.%';",
          );
          await customStatement(
            "UPDATE config_key_values SET key = replace(key, 'provider.onedrive_media.', "
            "'provider.media_onedrive.') WHERE key LIKE 'provider.onedrive_media.%';",
          );
        }
      }
      if (from < 37) {
        final ck = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='config_key_values';",
        ).get();
        if (ck.isNotEmpty) {
          await customStatement(
            "DELETE FROM config_key_values WHERE key IN ("
            "'microsoft.graph.client_id', 'google.client_id');",
          );
        }
      }
      if (from < 38) {
        await m.createTable(users);
        await m.createTable(userSessions);
        await m.createTable(userOauthIdentities);
      }
      if (from < 39) {
        final ps = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='provider_settings';",
        ).get();
        if (ps.isNotEmpty) {
          await customStatement(
            'ALTER TABLE provider_settings RENAME TO integrations;',
          );
        }
      }
      if (from < 35) {
        final overlayTable = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'display_overlay_schedules';",
        ).get();
        if (overlayTable.isNotEmpty) {
          final bounceDoc = displayOverlayConfigJsonDocForType(
            kOverlayTypeBouncingMessage,
          );
          await customStatement(
            'UPDATE display_overlay_schedules SET config_json_schema = ?, '
            'example_config_json = ? WHERE overlay_kind = ?',
            <Object?>[
              bounceDoc.schema,
              bounceDoc.example,
              kOverlayTypeBouncingMessage,
            ],
          );
        }
      }
      if (from < 41) {
        await _migrateOverlaysTableV41(this);
      }
      if (from < 42) {
        await _renameCuratorTablesV42(this);
      }
      if (from < 43) {
        await _migrateGuestWifiToWifiV43(this);
      }
      if (from < 44) {
        await _migrateTickerTapeMarqueeKvToConfigJsonV44(this);
      }
      if (from < 45) {
        await _renameCoreTablesV45(this);
      }
      if (from < 46) {
        final triviaTable = await customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name='trivia_questions' LIMIT 1",
        ).get();
        if (triviaTable.isNotEmpty) {
          await customStatement(
            'ALTER TABLE trivia_questions ADD COLUMN integration_id TEXT;',
          );
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );
}

String _mergeLegacyOverlaySchedulesRowForV41({
  required String configJson,
  required String messagesJson,
}) {
  Map<String, dynamic> cfg;
  try {
    final d = jsonDecode(configJson.trim().isEmpty ? '{}' : configJson);
    cfg = d is Map
        ? Map<String, dynamic>.from(d.map((k, v) => MapEntry(k.toString(), v)))
        : <String, dynamic>{};
  } on Object {
    cfg = <String, dynamic>{};
  }
  List<dynamic> rawList;
  try {
    final m = jsonDecode(messagesJson.trim().isEmpty ? '[]' : messagesJson);
    rawList = m is List ? m : <dynamic>[];
  } on Object {
    rawList = <dynamic>[];
  }
  final msgs = <String>[
    for (final e in rawList)
      if (e is String && e.trim().isNotEmpty) e.trim(),
  ];
  cfg['messages'] = msgs;
  return jsonEncode(cfg);
}

/// Renames legacy SQLite tables to match current [Table.tableName] values.
Future<void> _renameCoreTablesV45(AppDatabase db) async {
  await db.customStatement(
    'DROP VIEW IF EXISTS v_dashboard_alert_active_candidates;',
  );
  await db.customStatement('DROP VIEW IF EXISTS v_alert_active_candidates;');

  final hasDashboardAlerts = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type='table' "
    "AND name='dashboard_alerts' LIMIT 1",
  ).get();
  if (hasDashboardAlerts.isNotEmpty) {
    await db.customStatement('ALTER TABLE dashboard_alerts RENAME TO alerts;');
  }

  final hasScreenDefinitions = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type='table' "
    "AND name='screen_definitions' LIMIT 1",
  ).get();
  if (hasScreenDefinitions.isNotEmpty) {
    await db.customStatement(
      'ALTER TABLE screen_definitions RENAME TO screens;',
    );
  }

  final hasWeatherGovAlerts = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type='table' "
    "AND name='weather_gov_active_alerts' LIMIT 1",
  ).get();
  if (hasWeatherGovAlerts.isNotEmpty) {
    await db.customStatement(
      'ALTER TABLE weather_gov_active_alerts RENAME TO weather_alerts;',
    );
  }

  final hasWeatherCurrentData = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type='table' "
    "AND name='weather_current_data' LIMIT 1",
  ).get();
  if (hasWeatherCurrentData.isNotEmpty) {
    await db.customStatement(
      'ALTER TABLE weather_current_data RENAME TO weather_current;',
    );
  }

  await db.customStatement('''
CREATE VIEW IF NOT EXISTS v_alert_active_candidates AS
SELECT *
FROM alerts
WHERE dismissed_at IS NULL
ORDER BY priority DESC, created_at DESC;
''');
}

Future<void> _migrateOverlaysTableV41(AppDatabase db) async {
  final hasNew = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type='table' AND name='overlays' LIMIT 1",
  ).get();
  if (hasNew.isNotEmpty) {
    return;
  }
  final hasOld = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type='table' "
    "AND name='display_overlay_schedules' LIMIT 1",
  ).get();
  await db.customStatement(kEnsureOverlaysTableSql);
  if (hasOld.isEmpty) {
    return;
  }
  final rows = await db.customSelect('SELECT * FROM display_overlay_schedules').get();
  for (final r in rows) {
    final merged = _mergeLegacyOverlaySchedulesRowForV41(
      configJson: r.read<String>('config_json'),
      messagesJson: r.read<String>('messages_json'),
    );
    await db.customStatement(
      'INSERT OR REPLACE INTO overlays ('
      'id, enabled, overlay_type, label, config_json, config_json_schema, '
      'example_config_json, repeat_annually, year_exact, start_month, start_day, '
      'end_month, end_day, nth_week_of_month, nth_weekday) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        r.read<String>('id'),
        r.read<int>('enabled'),
        r.read<String>('overlay_kind'),
        r.read<String>('label'),
        merged,
        r.data['config_json_schema'],
        r.data['example_config_json'],
        r.read<int>('repeat_annually'),
        r.data['year_exact'],
        r.read<int>('start_month'),
        r.read<int>('start_day'),
        r.data['end_month'],
        r.data['end_day'],
        r.data['nth_week_of_month'],
        r.data['nth_weekday'],
      ],
    );
  }
  await db.customStatement('DROP TABLE display_overlay_schedules');
}

Future<void> _renameCuratorTablesV42(AppDatabase db) async {
  final ccOld = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type='table' "
    "AND name='content_categories' LIMIT 1",
  ).get();
  if (ccOld.isNotEmpty) {
    await db.customStatement(
      'ALTER TABLE content_categories RENAME TO curator_categories;',
    );
  }
  final rtOld = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type='table' "
    "AND name='reject_terms' LIMIT 1",
  ).get();
  if (rtOld.isNotEmpty) {
    await db.customStatement(
      'ALTER TABLE reject_terms RENAME TO curator_rejected_terms;',
    );
  }
}

Future<void> _migrateGuestWifiToWifiV43(AppDatabase db) async {
  String? screenTable;
  final hasScreens = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type='table' AND name='screens' LIMIT 1",
  ).get();
  if (hasScreens.isNotEmpty) {
    screenTable = 'screens';
  } else {
    final hasLegacy = await db.customSelect(
      "SELECT 1 FROM sqlite_master WHERE type='table' "
      "AND name='screen_definitions' LIMIT 1",
    ).get();
    if (hasLegacy.isNotEmpty) {
      screenTable = 'screen_definitions';
    }
  }
  if (screenTable == null) {
    return;
  }

  final screenCols = await db.customSelect(
    'PRAGMA table_info($screenTable);',
  ).get();
  final screenColNames = screenCols.map((r) => r.read<String>('name')).toSet();
  if (!screenColNames.contains('screen_type')) {
    return;
  }

  final hasKv = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type='table' "
    "AND name='config_key_values' LIMIT 1",
  ).get();
  final Map<String, String> kvValues;
  if (hasKv.isEmpty) {
    kvValues = <String, String>{};
  } else {
    kvValues = {
      for (final r in await db.select(db.configKeyValues).get()) r.key: r.value,
    };
  }

  const legacyDefaultKvKey = 'dashboard.guest_wifi.connection';

  final rows = await db.customSelect(
    'SELECT id, screen_type, config_json FROM $screenTable '
    "WHERE screen_type = 'guest_wifi';",
  ).get();

  for (final row in rows) {
    final id = row.read<String>('id');
    Map<String, dynamic> cfg = <String, dynamic>{};
    try {
      final raw = row.read<String>('config_json');
      final d = jsonDecode(raw.trim().isEmpty ? '{}' : raw);
      if (d is Map<String, dynamic>) {
        cfg = Map<String, dynamic>.from(d);
      } else if (d is Map) {
        cfg = Map<String, dynamic>.from(
          d.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    } on Object {
      cfg = <String, dynamic>{};
    }

    final kvKey = cfg['kvKey'] as String? ?? legacyDefaultKvKey;
    final fromCfg = cfg['connection'];
    final connectionFromCfg =
        fromCfg is String && fromCfg.trim().isNotEmpty ? fromCfg.trim() : null;
    final kvVal = kvValues[kvKey];
    final connection =
        connectionFromCfg ??
        (kvVal != null && kvVal.trim().isNotEmpty ? kvVal.trim() : null);

    final newCfg = <String, dynamic>{};
    if (connection != null && connection.isNotEmpty) {
      newCfg['connection'] = connection;
    }
    final headline = cfg['headline'];
    if (headline is String && headline.trim().isNotEmpty) {
      newCfg['headline'] = headline.trim();
    }

    final doc = screenConfigJsonDocForType('wifi');
    await db.customStatement(
      'UPDATE $screenTable SET screen_type = ?, config_json = ?, '
      'config_json_schema = ?, example_config_json = ? WHERE id = ?',
      <Object?>['wifi', jsonEncode(newCfg), doc.schema, doc.example, id],
    );
  }
}

Future<void> _migrateTickerTapeMarqueeKvToConfigJsonV44(AppDatabase db) async {
  final tickerTables = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type='table' AND name='ticker_tapes' LIMIT 1",
  ).get();
  if (tickerTables.isEmpty) {
    return;
  }

  final cols = await db.customSelect('PRAGMA table_info(ticker_tapes);').get();
  final colNames = cols.map((r) => r.read<String>('name')).toSet();
  if (!colNames.contains('config_json')) {
    await db.customStatement(
      "ALTER TABLE ticker_tapes ADD COLUMN config_json TEXT NOT NULL DEFAULT '{}'",
    );
  }

  Future<String?> kvLine(String key) async {
    final hasCfg = await db.customSelect(
      "SELECT 1 FROM sqlite_master WHERE type='table' "
      "AND name='config_key_values' LIMIT 1",
    ).get();
    if (hasCfg.isEmpty) {
      return null;
    }
    final rows = await db.customSelect(
      'SELECT value FROM config_key_values WHERE key = ?',
      variables: [Variable<String>(key)],
    ).get();
    if (rows.isEmpty) {
      return null;
    }
    return rows.first.read<String?>('value');
  }

  Future<void> mergeFallbackIntoTapeRow(String tapeId, String fallback) async {
    final rows = await db.customSelect(
      'SELECT config_json FROM ticker_tapes WHERE id = ?',
      variables: [Variable<String>(tapeId)],
    ).get();
    if (rows.isEmpty) {
      return;
    }
    final existingRaw = rows.first.read<String?>('config_json') ?? '{}';
    var cfg = <String, dynamic>{};
    try {
      final d = jsonDecode(existingRaw.trim().isEmpty ? '{}' : existingRaw);
      if (d is Map) {
        cfg = Map<String, dynamic>.from(
          d.map((k, Object? v) => MapEntry(k.toString(), v)),
        );
      }
    } on Object {
      cfg = <String, dynamic>{};
    }
    cfg['fallbackText'] = fallback;
    await db.customStatement(
      'UPDATE ticker_tapes SET config_json = ? WHERE id = ?',
      <Object?>[jsonEncode(cfg), tapeId],
    );
  }

  const bindings = <(String, String)>[
    ('ticker.marquee.weather', 'ticker_weather'),
    ('ticker.marquee.news', 'ticker_news'),
    ('ticker.marquee.quote', 'ticker_quote'),
  ];
  for (final b in bindings) {
    final v = await kvLine(b.$1);
    if (v != null && v.trim().isNotEmpty) {
      await mergeFallbackIntoTapeRow(b.$2, v.trim());
    }
  }

  final hasCfg = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type='table' "
    "AND name='config_key_values' LIMIT 1",
  ).get();
  if (hasCfg.isNotEmpty) {
    await db.customStatement(
      "DELETE FROM config_key_values WHERE key IN "
      "('ticker.marquee.weather','ticker.marquee.news','ticker.marquee.quote')",
    );
  }
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
