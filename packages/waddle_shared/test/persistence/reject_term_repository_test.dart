import 'package:test/test.dart';
import 'package:waddle_shared/persistence/reject_term_repository.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart';

void main() {
  test('listAll returns seeded defaults in alpha order by term', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final repo = RejectTermRepository(db);
    final all = await repo.listAll();
    expect(all.length, greaterThan(0));
    final terms = all.map((r) => r.term).toList();
    final sorted = List<String>.from(terms)..sort();
    expect(terms, sorted, reason: 'ordering should be alpha by term');
    await db.close();
  });

  test('upsert inserts a new term and assigns the default id', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final repo = RejectTermRepository(db);

    final input = RejectTermInput.parse(
      rawTerm: 'Foo',
      rawAction: 'block',
    )!;
    final id = await repo.upsert(input);
    expect(id, 'op_foo');

    final row = await repo.getById(id);
    expect(row, isNotNull);
    expect(row!.term, 'foo');
    expect(row.action, kRejectTermActionBlock);
    expect(row.createdAtMs, greaterThan(0));
    expect(row.updatedAtMs, row.createdAtMs);

    await db.close();
  });

  test('upsert by term updates an existing row instead of duplicating',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final repo = RejectTermRepository(db);

    final clock = DateTime(2024, 1, 1);
    final r1 = RejectTermRepository(db, now: () => clock);
    final firstId = await r1.upsert(
      RejectTermInput.parse(rawTerm: 'foo', rawAction: 'censor')!,
    );

    final r2 = RejectTermRepository(
      db,
      now: () => clock.add(const Duration(hours: 1)),
    );
    final secondId = await r2.upsert(
      RejectTermInput.parse(rawTerm: 'FOO', rawAction: 'block')!,
    );
    expect(secondId, firstId, reason: 'same term must reuse the same id');

    final all =
        (await repo.listAll()).where((r) => r.term == 'foo').toList();
    expect(all.length, 1);
    expect(all.single.action, kRejectTermActionBlock);
    expect(
      all.single.updatedAtMs,
      greaterThan(all.single.createdAtMs),
      reason: 'updatedAtMs must advance on the second upsert',
    );

    await db.close();
  });

  test('deleteById removes the row and returns the count', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final repo = RejectTermRepository(db);

    final id = await repo.upsert(
      RejectTermInput.parse(rawTerm: 'foo', rawAction: 'censor')!,
    );
    expect(await repo.getById(id), isNotNull);

    final removed = await repo.deleteById(id);
    expect(removed, 1);
    expect(await repo.getById(id), isNull);
    expect(await repo.deleteById(id), 0);

    await db.close();
  });

  test('deleteByTerm normalizes the term', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final repo = RejectTermRepository(db);
    await repo.upsert(
      RejectTermInput.parse(rawTerm: 'foo', rawAction: 'censor')!,
    );
    final removed = await repo.deleteByTerm('  FOO  ');
    expect(removed, 1);
    await db.close();
  });

  test('snapshotForFilter projects rows into RejectFilterTerm', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final repo = RejectTermRepository(db);
    await repo.upsert(
      RejectTermInput.parse(rawTerm: 'kappa', rawAction: 'block')!,
    );
    final snap = await repo.snapshotForFilter();
    final kappa = snap.firstWhere((t) => t.term == 'kappa');
    expect(kappa.action, kRejectTermActionBlock);
    await db.close();
  });

  group('RejectTermInput.parse', () {
    test('rejects empty term', () {
      expect(RejectTermInput.parse(rawTerm: '', rawAction: 'block'), isNull);
      expect(RejectTermInput.parse(rawTerm: '   ', rawAction: 'block'), isNull);
    });
    test('rejects unknown action', () {
      expect(
        RejectTermInput.parse(rawTerm: 'foo', rawAction: 'redact'),
        isNull,
      );
      expect(RejectTermInput.parse(rawTerm: 'foo', rawAction: null), isNull);
    });
    test('lowercases term and action', () {
      final p = RejectTermInput.parse(rawTerm: 'Foo', rawAction: 'BLOCK')!;
      expect(p.term, 'foo');
      expect(p.action, kRejectTermActionBlock);
    });
  });
}
