import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/seed/initial_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('schema 49 to 50 adds interests_stock_symbols.category', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
CREATE TABLE interests_stock_symbols (
  id TEXT NOT NULL PRIMARY KEY,
  symbol TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1
);
''');
        raw.execute(
          "INSERT INTO interests_stock_symbols (id, symbol, display_name, enabled) "
          "VALUES ('aapl', 'AAPL', 'Apple', 1)",
        );
        raw.execute('PRAGMA user_version = 49');
      },
    );
    final connection = DatabaseConnection(
      executor,
      closeStreamsSynchronously: true,
    );

    final db = AppDatabase(connection);
    await db.customStatement('SELECT 1');

    final row = await db
        .customSelect(
          'SELECT category FROM interests_stock_symbols WHERE id = ?',
          variables: [Variable<String>('aapl')],
        )
        .getSingle();
    expect(row.read<String>('category'), 'technology');

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);

    await db.close();
  });

  test(
    'schema 50 to 51 backfills null interests_stock_symbols.category',
    () async {
      final executor = NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
CREATE TABLE interests_stock_symbols (
  id TEXT NOT NULL PRIMARY KEY,
  symbol TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  category TEXT,
  enabled INTEGER NOT NULL DEFAULT 1
);
''');
          raw.execute(
            "INSERT INTO interests_stock_symbols (id, symbol, display_name, category, enabled) "
            "VALUES ('custom', 'CUST', '', NULL, 1)",
          );
          raw.execute('PRAGMA user_version = 50');
        },
      );
      final connection = DatabaseConnection(
        executor,
        closeStreamsSynchronously: true,
      );

      final db = AppDatabase(connection);
      await db.customStatement('SELECT 1');

      final row = await db
          .customSelect(
            'SELECT category FROM interests_stock_symbols WHERE id = ?',
            variables: [Variable<String>('custom')],
          )
          .getSingle();
      expect(row.read<String>('category'), 'general');

      final driftRow = await (db.select(
        db.interestsStockSymbols,
      )..where((t) => t.id.equals('custom'))).getSingle();
      expect(driftRow.category, 'general');

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), db.schemaVersion);

      await db.close();
    },
  );

  test('initial seed assigns stock symbol categories', () async {
    final db = openMemoryDatabase();
    await ensureInitialSeed(db);

    final rows = await db.select(db.interestsStockSymbols).get();
    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(row.category, isNotEmpty);
    }

    final aapl = rows.firstWhere((r) => r.id == 'aapl');
    expect(aapl.category, 'technology');
    final spy = rows.firstWhere((r) => r.id == 'spy');
    expect(spy.category, 'finance');

    await db.close();
  });
}
