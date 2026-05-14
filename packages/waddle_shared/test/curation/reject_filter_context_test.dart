import 'package:test/test.dart';
import 'package:waddle_shared/curation/reject_filter.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/reject_term_repository.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../helpers/memory_database.dart';

void main() {
  test('loadFromDb reads terms + format from a fresh DB (defaults seeded)',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    final ctx = await RejectFilterContext.loadFromDb(db);
    expect(ctx.isEmpty, isFalse);
    expect(ctx.format, CensorFormat.asterisksFull,
        reason: 'unset KV defaults to asterisks_full');

    await db.into(db.configKeyValues).insertOnConflictUpdate(
      ConfigKeyValuesCompanion.insert(
        key: kRejectCensorFormatKvKey,
        value: kRejectCensorFormatBracketedToken,
      ),
    );
    final ctx2 = await RejectFilterContext.loadFromDb(db);
    expect(ctx2.format, CensorFormat.bracketedToken);

    await db.close();
  });

  test('convenience censor/isBlocked delegates to the pure helpers', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.delete(db.rejectTerms).go();
    final repo = RejectTermRepository(db);
    await repo.upsert(
      RejectTermInput.parse(rawTerm: 'damn', rawAction: 'censor')!,
    );
    await repo.upsert(
      RejectTermInput.parse(rawTerm: 'shit', rawAction: 'block')!,
    );
    final ctx = await RejectFilterContext.loadFromDb(db);
    expect(ctx.censor('oh damn it'), 'oh **** it');
    expect(ctx.isBlocked('that is shit'), isTrue);
    expect(ctx.isBlocked('that is fine'), isFalse);
    expect(
      ctx.isMediaRejected(
        photographer: 'damn artist',
        altText: '',
        urls: const <String?>[],
      ),
      isTrue,
    );
    await db.close();
  });

  test('empty context short-circuits to no-op behavior', () {
    const ctx = RejectFilterContext.empty();
    expect(ctx.isEmpty, isTrue);
    expect(ctx.censor('shit damn'), 'shit damn');
    expect(ctx.isBlocked('shit damn'), isFalse);
    expect(
      ctx.isMediaRejected(
        photographer: 'damn artist',
        altText: 'damn',
        urls: const ['damn.jpg'],
      ),
      isFalse,
    );
  });
}
