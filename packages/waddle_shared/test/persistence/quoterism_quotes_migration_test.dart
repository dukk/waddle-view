import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 45 to 46 adds quoterism_quotes tables', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('PRAGMA user_version = 45');
    });
    final connection = DatabaseConnection(
      executor,
      closeStreamsSynchronously: true,
    );

    final db = AppDatabase(connection);
    await db.customStatement('SELECT 1');

    expect(await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='quoterism_quotes'",
    ).get(), isNotEmpty);
    expect(await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='quoterism_quote_categories'",
    ).get(), isNotEmpty);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);

    await db.close();
  });
}
