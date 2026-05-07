import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_display/persistence/database.dart';

void main() {
  test('v20 → v21 creates stock_symbols and stock_quotes tables', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('PRAGMA user_version = 20;');

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customStatement('SELECT 1');

    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('stock_symbols','stock_quotes')",
    ).get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(names, {'stock_symbols', 'stock_quotes'});
    await db.close();
  });
}
