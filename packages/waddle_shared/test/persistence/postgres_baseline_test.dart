import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/integration_accounts/integration_accounts_configured_sql.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/database_backend.dart';
import 'package:waddle_shared/persistence/database_executor.dart';
import 'package:waddle_shared/persistence/postgres_baseline.dart';

void main() {
  group('postgres baseline DDL', () {
    test('view statements use CREATE OR REPLACE VIEW', () {
      for (final sql in [
        kCreateVAlertActiveCandidatesViewPostgresSql,
        kCreateVIntegrationAccountsConfiguredViewPostgresSql,
      ]) {
        expect(sql, contains('CREATE OR REPLACE VIEW'));
        expect(sql, isNot(contains('IF NOT EXISTS')));
        expect(sql, isNot(contains('INSERT OR REPLACE')));
      }
    });

    test('sqlite integration accounts view keeps IF NOT EXISTS', () {
      expect(
        kCreateVIntegrationAccountsConfiguredViewSql,
        contains('CREATE VIEW IF NOT EXISTS'),
      );
    });

    test(
      'accounts_configured list predicates cast requires_accounts for Postgres',
      () {
        for (final sql in [
          kIntegrationsAccountsConfiguredSqlPredicate,
          kIntegrationsAccountsMissingSqlPredicate,
          kCreateVIntegrationAccountsConfiguredViewPostgresSql,
        ]) {
          expect(sql, contains('CAST(it.requires_accounts AS INTEGER)'));
          expect(sql, isNot(contains('requires_accounts = 1')));
        }
      },
    );
  });

  final testUrl =
      Platform.environment['WADDLE_DISPLAY_TEST_DATABASE_URL']?.trim() ??
      const String.fromEnvironment('WADDLE_DISPLAY_TEST_DATABASE_URL');

  test(
    'postgres baseline creates schema when URL is set',
    () async {
      if (testUrl.isEmpty) {
        return;
      }
      final db = AppDatabase(
        createPostgresExecutorFromUrl(testUrl),
        backend: WaddleDatabaseBackend.postgres,
      );
      try {
        await db.customStatement('select 1');
        final row = await db
            .customSelect('SELECT COUNT(*) AS c FROM integration_types')
            .getSingle();
        expect(row.read<int>('c'), greaterThanOrEqualTo(0));

        // Controller Integrations page always filters on accounts_configured.
        // Bare `requires_accounts = 1` fails on Postgres boolean columns.
        final configured = await db
            .customSelect(
              'SELECT COUNT(*) AS c FROM integrations '
              'WHERE $kIntegrationsAccountsConfiguredSqlPredicate',
            )
            .getSingle();
        expect(configured.read<int>('c'), greaterThanOrEqualTo(0));
        final missing = await db
            .customSelect(
              'SELECT COUNT(*) AS c FROM integrations '
              'WHERE $kIntegrationsAccountsMissingSqlPredicate',
            )
            .getSingle();
        expect(missing.read<int>('c'), greaterThanOrEqualTo(0));
      } finally {
        await db.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
