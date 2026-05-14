import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/reject_term_defaults.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/legacy_migration_schema_stubs.dart';
import '../helpers/memory_database.dart';

void main() {
  test('v30 -> v31 creates reject_terms and seeds defaults', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('PRAGMA user_version = 30;');
    stubContentCategoriesForMigration(raw);
    stubCalendarEventsAndBlobMetadataForMigration(raw);
    stubLegacyScreenDefinitionsForMigration(raw);

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customStatement('SELECT 1');

    final cols = await db
        .customSelect('PRAGMA table_info(reject_terms);')
        .get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll(<String>{
        'id',
        'term',
        'action',
        'created_at_ms',
        'updated_at_ms',
      }),
    );

    final rows = await db.select(db.rejectTerms).get();
    expect(
      rows.length,
      kDefaultRejectTermSeeds.length,
      reason: 'default reject terms seeded on first migration',
    );
    final terms = rows.map((r) => r.term).toSet();
    expect(terms.contains('fuck'), isTrue);
    expect(terms.contains('damn'), isTrue);

    final blockCount =
        rows.where((r) => r.action == kRejectTermActionBlock).length;
    expect(blockCount, greaterThan(0));
    final censorCount =
        rows.where((r) => r.action == kRejectTermActionCensor).length;
    expect(censorCount, greaterThan(0));

    await db.close();
  });

  test('fresh DB at v31 seeds reject_terms defaults', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final rows = await db.select(db.rejectTerms).get();
    expect(rows.length, kDefaultRejectTermSeeds.length);
    await db.close();
  });

  test('seed does not overwrite existing reject_terms rows on reopen',
      () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    final db1 = AppDatabase(NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    await db1.customStatement('SELECT 1');
    final initial = await db1.select(db1.rejectTerms).get();
    expect(initial.isNotEmpty, isTrue);
    await db1.delete(db1.rejectTerms).go();
    expect(await db1.select(db1.rejectTerms).get(), isEmpty);
    await db1.close();

    final db2 = AppDatabase(NativeDatabase.opened(raw));
    await db2.customStatement('SELECT 1');
    expect(
      await db2.select(db2.rejectTerms).get(),
      isEmpty,
      reason: 'beforeOpen must not re-seed after operator deleted all rows',
    );
    await db2.close();
  });
}
