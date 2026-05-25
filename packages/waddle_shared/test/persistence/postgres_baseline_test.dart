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
      } finally {
        await db.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
