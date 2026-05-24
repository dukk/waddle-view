import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/database_backend.dart';
import 'package:waddle_shared/persistence/database_executor.dart';

import '../global_options.dart';

/// Tables copied in FK-safe order for SQLite → Postgres migration.
const _tableOrder = <String>[
  'integration_types',
  'integration_type_required_accounts',
  'screen_types',
  'ticker_tape_types',
  'overlay_types',
  'integrations',
  'integration_accounts',
  'integration_account_links',
  'integrations_key_value',
  'integration_secrets',
  'secret_store_meta',
  'blob_metadata',
  'alerts',
  'config_key_values',
  'curator_categories',
  'curator_rejected_terms',
  'curator_configurations',
  'curator_schedule_rules',
  'curator_configuration_members',
  'curator_data_key_program_limits',
  'screens',
  'ticker_tapes',
  'overlays',
  'interests_rss_feeds',
  'news',
  'interests_facebook_sources',
  'interests_twitter_sources',
  'interests_linkedin_sources',
  'interests_jokes',
  'jokes',
  'joke_generation_batches',
  'quoterism_quotes',
  'quoterism_quote_categories',
  'interests_trivia',
  'trivia_questions',
  'trivia_generation_batches',
  'calendar_events',
  'calendar_event_categories',
  'interests_locations',
  'weather_current',
  'weather_alerts',
  'photos',
  'photo_categories',
  'videos',
  'video_categories',
  'pexels_fetch_batches',
  'interests_stock_symbols',
  'stock_quotes',
  'interests_home_assistant_entities',
  'home_assistant_entity_states',
  'adoption_pending',
  'api_clients',
  'cors_allowed_origins',
  'installed_plugins',
  'runtime_signals',
  'task_lists',
  'tasks',
];

const _integerBooleanColumns = <String, Set<String>>{
  'integrations': {'enabled'},
  'integration_accounts': {'enabled'},
  'screens': {'enabled'},
  'ticker_tapes': {'enabled'},
  'curator_configurations': {'enabled'},
};

class DbCommand extends Command<void> {
  DbCommand(this.globalOptions) : super() {
    addSubcommand(_DbMigrateToPostgres(globalOptions));
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'db';

  @override
  String get description => 'Database utilities (SQLite ↔ Postgres).';
}

class _DbMigrateToPostgres extends Command<void> {
  _DbMigrateToPostgres(this.globalOptions) : super() {
    argParser
      ..addOption(
        'to',
        help: 'Target Postgres URL (default: WADDLE_DISPLAY_DATABASE_URL).',
      )
      ..addFlag('dry-run', negatable: false, help: 'Compare row counts only.')
      ..addFlag(
        'force',
        negatable: false,
        help: 'Overwrite non-empty Postgres target.',
      );
  }

  final GlobalCliOptions globalOptions;

  @override
  String get name => 'migrate-to-postgres';

  @override
  String get description =>
      'Copy display data from local SQLite to PostgreSQL.';

  @override
  Future<void> run() async {
    final sqliteFile = globalOptions.databaseFile;
    if (!sqliteFile.existsSync()) {
      stderr.writeln('SQLite file not found: ${sqliteFile.path}');
      exitCode = 1;
      return;
    }
    final toUrl =
        (argResults!['to'] as String?)?.trim() ??
        Platform.environment['WADDLE_DISPLAY_DATABASE_URL']?.trim();
    if (toUrl == null || toUrl.isEmpty) {
      stderr.writeln('Set --to or WADDLE_DISPLAY_DATABASE_URL');
      exitCode = 1;
      return;
    }
    final dryRun = argResults!['dry-run'] as bool;
    final force = argResults!['force'] as bool;

    final sqliteDb = AppDatabase(
      LazyDatabase(() async => NativeDatabase.createInBackground(sqliteFile)),
    );
    final postgresDb = AppDatabase(
      createPostgresExecutorFromUrl(toUrl),
      backend: WaddleDatabaseBackend.postgres,
    );

    try {
      if (!dryRun) {
        await postgresDb.customStatement('select 1');
      }

      var targetRows = 0;
      if (!dryRun) {
        for (final table in _tableOrder) {
          final count = await postgresDb
              .customSelect('SELECT COUNT(*) AS c FROM $table')
              .getSingle();
          targetRows += count.read<int>('c');
        }
      }

      if (targetRows > 0 && !force && !dryRun) {
        stderr.writeln(
          'Target Postgres database is not empty. Re-run with --force.',
        );
        exitCode = 1;
        return;
      }

      if (!dryRun && (force || targetRows == 0)) {
        for (final table in _tableOrder.reversed) {
          await postgresDb.customStatement('DELETE FROM $table');
        }
      }

      for (final table in _tableOrder) {
        final rows = await sqliteDb.customSelect('SELECT * FROM $table').get();
        stdout.writeln('$table: ${rows.length} rows (source)');
        if (dryRun || rows.isEmpty) continue;

        for (final row in rows) {
          final data = row.data;
          final columns = data.keys.toList();
          final values = columns
              .map((c) => _mapValue(table, c, data[c]))
              .toList();
          final placeholders = List.generate(
            columns.length,
            (_) => '?',
          ).join(', ');
          await postgresDb.customStatement(
            'INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders)',
            values,
          );
        }
      }

      stdout.writeln(dryRun ? 'Dry run complete.' : 'Migration complete.');
    } finally {
      await sqliteDb.close();
      await postgresDb.close();
    }
  }
}

Object? _mapValue(String table, String column, Object? value) {
  final boolCols = _integerBooleanColumns[table];
  if (boolCols != null && boolCols.contains(column) && value is int) {
    return value != 0;
  }
  return value;
}
