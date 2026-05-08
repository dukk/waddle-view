import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/data/seed/tables/trivia_categories_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('ensureDefaultTriviaCategories inserts rows once with seasonal entries', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureDefaultTriviaCategories(db);
    final first = await db.select(db.triviaCategories).get();
    expect(first.length, 13);

    final seasonalIds = first.where((row) => row.isSeasonal).map((row) => row.id);
    expect(
      seasonalIds,
      containsAll(<String>['christmas', 'easter', 'halloween', 'thanksgiving']),
    );

    await ensureDefaultTriviaCategories(db);
    final second = await db.select(db.triviaCategories).get();
    expect(second.length, 13);
  });
}
