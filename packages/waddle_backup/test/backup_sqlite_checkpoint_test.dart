import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:waddle_backup/backup_sqlite_checkpoint.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('walCheckpointFull leaves readable sqlite', () async {
    final tmp = Directory.systemTemp.createTempSync('waddle_bu_ck');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final dbFile = File(p.join(tmp.path, 'waddle_display.db'));
    final db = AppDatabase(createQueryExecutorForFile(dbFile));
    await db.customStatement('CREATE TABLE IF NOT EXISTS t (a INTEGER);');
    await db.customStatement('INSERT INTO t VALUES (42);');
    await db.close();
    await walCheckpointFull(dbFile);
    final db2 = AppDatabase(createQueryExecutorForFile(dbFile));
    final rows = await db2.customSelect('SELECT a FROM t').get();
    expect(rows.single.data['a'], 42);
    await db2.close();
  });
}
