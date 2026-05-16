import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('v39 renames ticker_definitions table to ticker_tapes', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE ticker_definitions (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1,
  ticker_type TEXT NOT NULL,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  sort_order INTEGER NOT NULL DEFAULT 0,
  config_key TEXT,
  config_json_schema TEXT,
  example_config_json TEXT
);
''');
    raw.execute(
      "INSERT INTO ticker_definitions (id, name, ticker_type) "
      "VALUES ('legacy_row','Legacy','time');",
    );
    raw.execute('PRAGMA user_version = 39;');

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customSelect('SELECT 1').get();

    final names = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name IN ('ticker_definitions','ticker_tapes');",
        )
        .get();
    final tableNames = names.map((r) => r.read<String>('name')).toSet();
    expect(tableNames.contains('ticker_tapes'), isTrue);
    expect(tableNames.contains('ticker_definitions'), isFalse);

    final ver = await db.customSelect('PRAGMA user_version').getSingle();
    expect(ver.read<int>('user_version'), 46);

    final row = await (db.select(db.tickerTapes)
          ..where((t) => t.id.equals('legacy_row')))
        .getSingle();
    expect(row.tickerType, 'time');
    expect(row.name, 'Legacy');

    await db.close();
  });
}
