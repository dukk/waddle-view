import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 3 to 4 adds installed_plugins and runtime_signals tables', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('PRAGMA user_version = 3');
    });
    final connection = DatabaseConnection(
      executor,
      closeStreamsSynchronously: true,
    );

    final db = AppDatabase(connection);
    await db.customStatement('SELECT 1');

    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('installed_plugins', 'runtime_signals')",
    ).get();
    expect(tables.length, 2);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 4);

    await db.close();
  });
}
