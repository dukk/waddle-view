import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/auth/adoption_repository.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('beforeOpen at schema 48 creates missing adoption tables', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('PRAGMA user_version = 48');
      },
    );
    final connection = DatabaseConnection(
      executor,
      closeStreamsSynchronously: true,
    );

    final db = AppDatabase(connection);
    addTearDown(db.close);

    await db.customStatement('SELECT 1');

    for (final name in [
      'adoption_pending',
      'api_clients',
      'cors_allowed_origins',
    ]) {
      final row = await db
          .customSelect(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1",
            variables: [Variable<String>(name)],
          )
          .getSingleOrNull();
      expect(row, isNotNull, reason: 'expected table $name');
    }

    final cols = await db.customSelect('PRAGMA table_info(api_clients)').get();
    final colNames = cols.map((r) => r.read<String>('name')).toSet();
    expect(colNames, contains('referrer_origin'));

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);
  });

  test('api_clients rows persist across database reopen', () async {
    final dir = Directory.systemTemp.createTempSync('waddle_adopt_test_');
    final file = File('${dir.path}/waddle_display.db');
    addTearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    const instanceId = 'adoption-persist-test-instance-id-0123456789ab';
    final db1 = AppDatabase(NativeDatabase(file));
    final repo1 = AdoptionRepository(db1, instanceId: instanceId);

    final nowMs = DateTime.utc(2026, 5, 22).millisecondsSinceEpoch;
    final granted = await repo1.grantInstant(
      identifier: 'controller-test',
      role: 'operator',
      nowMs: nowMs,
    );
    await db1.close();

    final db2 = AppDatabase(NativeDatabase(file));
    addTearDown(db2.close);
    final repo2 = AdoptionRepository(db2, instanceId: instanceId);
    final client = await repo2.clientForApiKey(granted.apiKey);
    expect(client, isNotNull);
    expect(client!.identifier, 'controller-test');
    expect(client.role, 'operator');
  });
}
