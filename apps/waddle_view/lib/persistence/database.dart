import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../debug/app_debug_log.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    ProviderSettings,
    BlobMetadata,
    DashboardAlerts,
    DashboardKv,
    ScreenDefinitions,
    CuratorDataKeyProgramLimits,
    CuratorSettings,
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await customStatement('''
CREATE TABLE IF NOT EXISTS category_icons (
  category_type TEXT NOT NULL,
  category_id TEXT NOT NULL,
  blob_key TEXT NOT NULL,
  prompt TEXT NULL,
  generated_by TEXT NOT NULL DEFAULT 'manual',
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY (category_type, category_id)
);
''');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_category_icons_blob_key '
        'ON category_icons(blob_key);',
      );
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
        await m.createTable(curatorSettings);
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
      if (from < 13) {
        await customStatement('''
CREATE TABLE IF NOT EXISTS category_icons (
  category_type TEXT NOT NULL,
  category_id TEXT NOT NULL,
  blob_key TEXT NOT NULL,
  prompt TEXT NULL,
  generated_by TEXT NOT NULL DEFAULT 'manual',
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY (category_type, category_id)
);
''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_category_icons_blob_key '
          'ON category_icons(blob_key);',
        );
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
