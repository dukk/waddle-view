import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:waddle_backup/waddle_backup_service.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('create and restore round-trip', () async {
    final tmp = Directory.systemTemp.createTempSync('waddle_bu_svc');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final dbFile = File(p.join(tmp.path, 'waddle_display.db'));
    final db = AppDatabase(createQueryExecutorForFile(dbFile));
    await db.customStatement('CREATE TABLE IF NOT EXISTS t (a INTEGER);');
    await db.customStatement('INSERT INTO t VALUES (7);');
    await db.close();

    final media = Directory(p.join(tmp.path, 'media', 'aa'));
    await media.create(recursive: true);
    await File(p.join(media.path, 'blob.bin')).writeAsBytes([8, 9]);

    final service = WaddleBackupService(databaseFile: dbFile);
    final created = await service.createArchive(
      const WaddleBackupCreateOptions(creatorVersion: 'test'),
    );
    expect(created.bytes.length, greaterThan(100));

    await dbFile.writeAsBytes([0]);
    final restored = await service.restoreArchive(
      created.bytes,
      confirmYes: true,
    );
    expect(restored.manifest.includeDatabase, isTrue);
    expect(restored.manifest.includeBlobs, isTrue);

    final db2 = AppDatabase(createQueryExecutorForFile(dbFile));
    final rows = await db2.customSelect('SELECT a FROM t').get();
    expect(rows.single.data['a'], 7);
    await db2.close();
    expect(
      File(p.join(tmp.path, 'media', 'aa', 'blob.bin')).readAsBytesSync(),
      [8, 9],
    );
  });
}
