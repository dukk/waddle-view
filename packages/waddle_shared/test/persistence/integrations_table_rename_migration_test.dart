import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('v38 renames provider_settings table to integrations', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE provider_settings (
  id TEXT NOT NULL PRIMARY KEY,
  provider_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  base_url TEXT,
  config_json TEXT,
  config_json_schema TEXT,
  example_config_json TEXT
);
''');
    raw.execute(
      "INSERT INTO provider_settings (id, provider_type) VALUES ('stub','stub');",
    );
    raw.execute('PRAGMA user_version = 38;');

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customStatement('SELECT 1');

    final names = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name IN ('provider_settings','integrations');",
        )
        .get();
    final tableNames = names.map((r) => r.read<String>('name')).toSet();
    expect(tableNames.contains('integrations'), isTrue);
    expect(tableNames.contains('provider_settings'), isFalse);

    final ver = await db.customSelect('PRAGMA user_version').getSingle();
    expect(ver.read<int>('user_version'), 48);

    final row = await (db.select(db.integrations)..where((t) => t.id.equals('stub')))
        .getSingle();
    expect(row.providerType, 'stub');

    await db.close();
  });
}
