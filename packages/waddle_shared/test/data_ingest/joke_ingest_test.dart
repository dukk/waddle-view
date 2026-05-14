import 'package:test/test.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/data_ingest/joke_ingest.dart';
import 'package:waddle_shared/data_model/joke_candidate.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test('ingestJokeCandidates inserts and respects stable id', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(id: 'c1', label: 'One'),
        );
    final reject = await RejectFilterContext.loadFromDb(db);
    final n = await ingestJokeCandidates(
      db: db,
      rejectCtx: reject,
      allowedCategoryIds: const {'c1'},
      createdAt: DateTime.utc(2026, 1, 1),
      candidates: const [
        JokeCandidate(
          categoryId: 'c1',
          setup: 'Why did the duck?',
          punchline: 'Waddle.',
        ),
      ],
    );
    expect(n, 1);
    final rows = await db.select(db.jokes).get();
    expect(rows, hasLength(1));
    expect(
      rows.single.id,
      jokeStableId('c1', 'Why did the duck?', 'Waddle.'),
    );
    await db.close();
  });

  test('ingestJokeCandidates skips unknown categories', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final reject = await RejectFilterContext.loadFromDb(db);
    final n = await ingestJokeCandidates(
      db: db,
      rejectCtx: reject,
      allowedCategoryIds: const {'c1'},
      createdAt: DateTime.utc(2026, 1, 1),
      candidates: const [
        JokeCandidate(
          categoryId: 'missing',
          setup: 'a',
          punchline: 'b',
        ),
      ],
    );
    expect(n, 0);
    expect(await db.select(db.jokes).get(), isEmpty);
    await db.close();
  });
}
