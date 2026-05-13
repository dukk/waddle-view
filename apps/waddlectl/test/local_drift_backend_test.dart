import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:waddle_display/persistence/database.dart';
import 'package:waddle_display/secrets/in_memory_secret_store.dart';
import 'package:waddlectl/local_drift_backend.dart';

void main() {
  test('LocalDriftBackend config round-trip on temp sqlite', () async {
    final tmp = Directory.systemTemp.createTempSync('waddlectl_db');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on Object {
        // Best-effort; temp dir may be locked or already removed.
      }
    });
    final dbFile = File(p.join(tmp.path, 'waddle_view.sqlite'));
    final db = AppDatabase(createQueryExecutorForFile(dbFile));
    final secrets = InMemorySecretStore();
    final backend = LocalDriftBackend(db, secrets);
    addTearDown(() async {
      await backend.close();
    });

    await backend.setConfig('waddlectl.test_key', 'hello');
    expect(await backend.getConfig('waddlectl.test_key'), 'hello');
    final rows = await backend.listConfig();
    expect(rows.any((e) => e['key'] == 'waddlectl.test_key'), isTrue);
    await backend.unsetConfig('waddlectl.test_key');
    expect(await backend.getConfig('waddlectl.test_key'), isNull);
  });

  test('updateScreen mutates row', () async {
    final tmp = Directory.systemTemp.createTempSync('waddlectl_db2');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on Object {
        // Best-effort; temp dir may be locked or already removed.
      }
    });
    final dbFile = File(p.join(tmp.path, 'waddle_view.sqlite'));
    final db = AppDatabase(createQueryExecutorForFile(dbFile));
    final backend = LocalDriftBackend(db, InMemorySecretStore());
    addTearDown(() async {
      await backend.close();
    });

    await db
        .into(db.screenDefinitions)
        .insert(
          ScreenDefinitionsCompanion.insert(
            id: 'waddlectl_test_screen',
            name: 'T',
            screenType: 'clock',
          ),
        );

    await backend.updateScreen(
      id: 'waddlectl_test_screen',
      name: 'Renamed',
      dwellSeconds: 12,
    );
    final row = await backend.describeScreen('waddlectl_test_screen');
    expect(row!['name'], 'Renamed');
    expect(row['dwell_seconds'], 12);
  });
}
