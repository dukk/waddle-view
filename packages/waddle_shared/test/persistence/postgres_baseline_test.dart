import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/database_backend.dart';
import 'package:waddle_shared/persistence/database_executor.dart';

void main() {
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
