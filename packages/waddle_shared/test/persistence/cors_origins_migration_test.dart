import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('v47 -> v48 adds cors_allowed_origins and api_clients.referrer_origin',
      () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE adoption_pending (
  id TEXT NOT NULL PRIMARY KEY,
  identifier TEXT NOT NULL,
  role TEXT NOT NULL,
  issued_at_ms INTEGER NOT NULL,
  expires_at_ms INTEGER NOT NULL,
  challenge_hash TEXT NOT NULL,
  nonce TEXT NOT NULL,
  alert_id INTEGER
);
''');
    raw.execute('''
CREATE TABLE api_clients (
  id TEXT NOT NULL PRIMARY KEY,
  identifier TEXT NOT NULL,
  role TEXT NOT NULL,
  api_key_hash TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
    raw.execute('PRAGMA user_version = 47;');

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customStatement('SELECT 1');

    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('cors_allowed_origins', 'api_clients');",
    ).get();
    expect(tables.length, 2);

    final cols = await db.customSelect('PRAGMA table_info(api_clients)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names.contains('referrer_origin'), isTrue);

    final ver = await db.customSelect('PRAGMA user_version').getSingle();
    expect(ver.read<int>('user_version'), 48);

    await db.close();
  });

  test(
    'v47 -> v48 skips referrer_origin when column already exists (v47 createTable)',
    () async {
      final raw = sqlite.sqlite3.openInMemory();
      raw.execute('PRAGMA foreign_keys = ON;');
      raw.execute('''
CREATE TABLE adoption_pending (
  id TEXT NOT NULL PRIMARY KEY,
  identifier TEXT NOT NULL,
  role TEXT NOT NULL,
  issued_at_ms INTEGER NOT NULL,
  expires_at_ms INTEGER NOT NULL,
  challenge_hash TEXT NOT NULL,
  nonce TEXT NOT NULL,
  alert_id INTEGER
);
''');
      raw.execute('''
CREATE TABLE api_clients (
  id TEXT NOT NULL PRIMARY KEY,
  identifier TEXT NOT NULL,
  role TEXT NOT NULL,
  api_key_hash TEXT NOT NULL,
  referrer_origin TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
      raw.execute('PRAGMA user_version = 47;');

      final db = AppDatabase(NativeDatabase.opened(raw));
      await db.customStatement('SELECT 1');

      final ver = await db.customSelect('PRAGMA user_version').getSingle();
      expect(ver.read<int>('user_version'), 48);

      await db.close();
    },
  );
}
