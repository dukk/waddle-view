import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('v46 -> v47 drops user auth tables and creates adoption tables', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE users (
  id TEXT NOT NULL PRIMARY KEY,
  username TEXT NOT NULL,
  username_lower TEXT NOT NULL,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL,
  password_hash TEXT,
  is_bootstrap INTEGER NOT NULL DEFAULT 0,
  disabled_at_ms INTEGER,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
    raw.execute('''
CREATE TABLE user_sessions (
  id TEXT NOT NULL PRIMARY KEY,
  user_id TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  expires_at_ms INTEGER NOT NULL,
  client_label TEXT
);
''');
    raw.execute('''
CREATE TABLE user_oauth_identities (
  user_id TEXT NOT NULL,
  provider TEXT NOT NULL,
  subject TEXT NOT NULL,
  PRIMARY KEY (user_id, provider)
);
''');
    raw.execute('PRAGMA user_version = 46;');

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customStatement('SELECT 1');

    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('users', 'user_sessions', 'user_oauth_identities', "
      "'adoption_pending', 'api_clients');",
    ).get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names.contains('users'), isFalse);
    expect(names.contains('user_sessions'), isFalse);
    expect(names.contains('user_oauth_identities'), isFalse);
    expect(names.contains('adoption_pending'), isTrue);
    expect(names.contains('api_clients'), isTrue);

    final ver = await db.customSelect('PRAGMA user_version').getSingle();
    expect(ver.read<int>('user_version'), 48);

    await db.close();
  });
}
