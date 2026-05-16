import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_shared/config/google_kv.dart';
import 'package:waddle_shared/config/microsoft_graph_kv.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('v36 -> v39 removes oauth client id rows from config_key_values', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE config_key_values (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
    raw.execute(
      "INSERT INTO config_key_values VALUES ('$kMicrosoftGraphClientIdKvKey', 'ms-id');",
    );
    raw.execute(
      "INSERT INTO config_key_values VALUES ('$kGoogleClientIdKvKey', 'g-id');",
    );
    raw.execute('PRAGMA user_version = 36;');

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customStatement('SELECT 1');

    final rows = await db.select(db.configKeyValues).get();
    final keys = rows.map((r) => r.key).toSet();
    expect(keys.contains(kMicrosoftGraphClientIdKvKey), isFalse);
    expect(keys.contains(kGoogleClientIdKvKey), isFalse);

    final ver = await db.customSelect('PRAGMA user_version').getSingle();
    expect(ver.read<int>('user_version'), 46);

    await db.close();
  });
}
