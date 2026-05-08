import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../debug/app_debug_log.dart';
import 'config_json_documentation.dart';
import 'content_category_defaults.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    ContentCategories,
    ProviderSettings,
    BlobMetadata,
    DashboardAlerts,
    ConfigKeyValues,
    ScreenDefinitions,
    TickerDefinitions,
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
    WeatherCurrentData,
    WeatherGovActiveAlerts,
    Photos,
    Videos,
    PexelsFetchBatches,
    StockSymbols,
    StockQuotes,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 26;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await customStatement('''
CREATE VIEW IF NOT EXISTS v_dashboard_alert_active_candidates AS
SELECT *
FROM dashboard_alerts
WHERE dismissed_at IS NULL
ORDER BY priority DESC, created_at DESC;
''');
    },
    onUpgrade: (Migrator m, int from, int to) async {
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
        await m.createTable(screenDefinitions);
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
        await m.createTable(weatherCurrentData);
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
        final legacy =
            legacyTables.map((r) => r.read<String>('name')).toSet();
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
          final rows =
              await customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'table' "
                    "AND name = '$table';",
                  )
                  .get();
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
          final providerRows = await select(providerSettings).get();
          for (final p in providerRows) {
            final doc = providerConfigJsonDocForType(p.providerType);
            await (update(providerSettings)
                  ..where((t) => t.id.equals(p.id)))
                .write(
                  ProviderSettingsCompanion(
                    configJsonSchema: Value(doc.schema),
                    exampleConfigJson: Value(doc.example),
                  ),
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
          final screenRows = await select(screenDefinitions).get();
          for (final s in screenRows) {
            await (update(screenDefinitions)
                  ..where((t) => t.id.equals(s.id)))
                .write(
                  ScreenDefinitionsCompanion(
                    layoutJsonSchema: Value(kScreenLayoutJsonSchema),
                    exampleLayoutJson: Value(kExampleScreenLayoutJson),
                  ),
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
        await m.createTable(tickerDefinitions);
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
        await m.createTable(weatherGovActiveAlerts);
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
          final rows =
              await customSelect('PRAGMA table_info($table);').get();
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
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );
}

/// Opens a file-backed SQLite database under application support.
QueryExecutor createQueryExecutor() {
  return LazyDatabase(() async {
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'waddle_view.sqlite'));
    AppDebugLog.startup('SQLite database file: ${file.path}');
    return NativeDatabase.createInBackground(file);
  });
}
