import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/reject_term_defaults.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart';

void main() {
  test('kDefaultRejectTermSeeds has unique ids, terms, and valid actions', () {
    expect(kDefaultRejectTermSeeds.length, 162);

    final ids = <String>{};
    final terms = <String>{};
    for (final seed in kDefaultRejectTermSeeds) {
      expect(seed.id, startsWith('default_'));
      expect(seed.term, seed.term.toLowerCase());
      expect(
        seed.action,
        anyOf(kRejectTermActionBlock, kRejectTermActionCensor),
      );
      expect(ids.add(seed.id), isTrue, reason: 'duplicate id ${seed.id}');
      expect(terms.add(seed.term), isTrue, reason: 'duplicate term ${seed.term}');
    }
  });

  test('fresh database seeds default reject terms', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);

    final rows = await db.select(db.rejectTerms).get();
    expect(rows.length, kDefaultRejectTermSeeds.length);

    final seededIds = kDefaultRejectTermSeeds.map((s) => s.id).toSet();
    final dbIds = rows.map((r) => r.id).toSet();
    expect(dbIds, seededIds);

    final block = rows.firstWhere((r) => r.id == 'default_fuck');
    expect(block.action, kRejectTermActionBlock);
    final censor = rows.firstWhere((r) => r.id == 'default_damn');
    expect(censor.action, kRejectTermActionCensor);
    final slur = rows.firstWhere((r) => r.id == 'default_porn');
    expect(slur.action, kRejectTermActionBlock);
  });

  test('ensureDefaultRejectTerms adds missing defaults without duplicating custom rows',
      () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);

    await db.delete(db.rejectTerms).go();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.rejectTerms).insert(
          RejectTermsCompanion.insert(
            id: 'op_custom',
            term: 'customword',
            action: kRejectTermActionBlock,
            createdAtMs: nowMs,
            updatedAtMs: nowMs,
          ),
        );

    await ensureDefaultRejectTerms(db);
    var rows = await db.select(db.rejectTerms).get();
    expect(rows.length, kDefaultRejectTermSeeds.length + 1);
    expect(rows.any((r) => r.id == 'op_custom'), isTrue);
    expect(rows.any((r) => r.id == 'default_porn'), isTrue);

    await ensureDefaultRejectTerms(db);
    rows = await db.select(db.rejectTerms).get();
    expect(rows.length, kDefaultRejectTermSeeds.length + 1);
  });

  test('ensureDefaultRejectTerms does not overwrite existing default rows', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.rejectTerms)..where((t) => t.id.equals('default_damn')))
        .write(
      RejectTermsCompanion(
        action: const Value(kRejectTermActionBlock),
        updatedAtMs: Value(nowMs),
      ),
    );

    await ensureDefaultRejectTerms(db);
    final row = await (db.select(db.rejectTerms)
          ..where((t) => t.id.equals('default_damn')))
        .getSingle();
    expect(row.action, kRejectTermActionBlock);
  });
}
