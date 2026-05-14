import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:waddlectl/export_sqlite_seed_sql.dart';
import 'package:waddlectl/run_app.dart';

void main() {
  test('formatSqliteSeedLiteral', () {
    expect(formatSqliteSeedLiteral(null), 'NULL');
    expect(formatSqliteSeedLiteral("a'b"), "'a''b'");
    expect(formatSqliteSeedLiteral(42), '42');
    expect(formatSqliteSeedLiteral(true), '1');
    expect(formatSqliteSeedLiteral(false), '0');
    expect(formatSqliteSeedLiteral(Uint8List.fromList([0, 255])), "X'00ff'");
  });

  test('export round trip minimal FK', () {
    final tmp = Directory.systemTemp.createTempSync('wctl_export_seed');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final dbPath = p.join(tmp.path, 'waddle_view.sqlite');

    final db = sqlite3.open(dbPath, mode: OpenMode.readWriteCreate);
    try {
      db.execute(
        'CREATE TABLE parent (id TEXT NOT NULL PRIMARY KEY, label TEXT NOT NULL);',
      );
      db.execute('''
CREATE TABLE child (
  id TEXT NOT NULL PRIMARY KEY,
  parent_id TEXT NOT NULL,
  FOREIGN KEY(parent_id) REFERENCES parent(id)
);
''');
      db.execute("INSERT INTO parent (id, label) VALUES ('p1', 'x');");
      db.execute("INSERT INTO child (id, parent_id) VALUES ('c1', 'p1');");
    } finally {
      db.close();
    }

    final sql = exportSqliteSeedSql(File(dbPath));
    expect(sql, contains('DELETE FROM "child";'));
    expect(sql, contains('DELETE FROM "parent";'));
    expect(sql, contains('INSERT INTO "parent"'));
    expect(sql, contains('INSERT INTO "child"'));
    expect(sql, contains('PRAGMA foreign_keys=OFF;'));
    expect(sql, contains('COMMIT;'));

    final targetPath = p.join(tmp.path, 'target.sqlite');
    final db2 = sqlite3.open(targetPath, mode: OpenMode.readWriteCreate);
    try {
      db2.execute(
        'CREATE TABLE parent (id TEXT NOT NULL PRIMARY KEY, label TEXT NOT NULL);',
      );
      db2.execute('''
CREATE TABLE child (
  id TEXT NOT NULL PRIMARY KEY,
  parent_id TEXT NOT NULL,
  FOREIGN KEY(parent_id) REFERENCES parent(id)
);
''');
      db2.execute(sql);
      final nP =
          db2.select('SELECT COUNT(*) AS c FROM parent').first.columnAt(0)
              as int;
      final nC =
          db2.select('SELECT COUNT(*) AS c FROM child').first.columnAt(0)
              as int;
      expect(nP, 1);
      expect(nC, 1);
    } finally {
      db2.close();
    }
  });

  test('formatSqliteSeedLiteral rejects non-finite double', () {
    expect(() => formatSqliteSeedLiteral(double.nan), throwsArgumentError);
  });

  test('sqlite export-seed CLI missing database', () async {
    final dir = Directory.systemTemp.createTempSync('wctl_export_miss');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bad = p.join(dir.path, 'missing.sqlite');
    expect(
      await runWaddlectl([
        '--database',
        bad,
        'sqlite',
        'export-seed',
        '--stdout',
      ]),
      1,
    );
  });
}
