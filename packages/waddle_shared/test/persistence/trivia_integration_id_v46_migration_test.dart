import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('v45 -> v46 adds trivia_questions.integration_id', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE trivia_categories (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  is_seasonal INTEGER NOT NULL DEFAULT 0,
  start_month INTEGER,
  start_day INTEGER,
  end_month INTEGER,
  end_day INTEGER,
  category_prompt TEXT,
  min_questions INTEGER NOT NULL DEFAULT 10,
  max_questions INTEGER NOT NULL DEFAULT 100
);
''');
    raw.execute("INSERT INTO trivia_categories (id, label) VALUES ('general', 'General');");
    raw.execute('''
CREATE TABLE trivia_questions (
  id TEXT NOT NULL PRIMARY KEY,
  category_id TEXT NOT NULL REFERENCES trivia_categories(id),
  question TEXT NOT NULL,
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  option_c TEXT NOT NULL,
  option_d TEXT NOT NULL,
  correct_option TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  suppressed INTEGER NOT NULL DEFAULT 0
);
''');
    raw.execute('PRAGMA user_version = 45;');

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customSelect('SELECT 1').get();

    final cols = await db.customSelect('PRAGMA table_info(trivia_questions)').get();
    final names = cols.map((r) => r.data['name'] as String).toList();
    expect(names, contains('integration_id'));

    final ver = await db.customSelect('PRAGMA user_version').getSingle();
    expect(ver.read<int>('user_version'), 48);

    await db.close();
  });
}
