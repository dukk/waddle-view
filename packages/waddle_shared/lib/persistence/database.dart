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
    AdoptionPending,
    ApiClients,
    CorsAllowedOrigins,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

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
      throw UnsupportedError(
        'Database schema reset at version 1. Delete the SQLite file and '
        'reinstall (fresh seed). Cannot upgrade from version $from.',
      );
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
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
