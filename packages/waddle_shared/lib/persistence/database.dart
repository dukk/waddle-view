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
    RejectTerms,
    AdoptionPending,
    ApiClients,
    CorsAllowedOrigins,
    IntegrationSecrets,
    SecretStoreMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

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
