import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/seed/tables/interests_trivia_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('ensureDefaultInterestsTrivia inserts rows once with seasonal entries', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await ensureDefaultInterestsTrivia(db);
    final first = await db.select(db.interestsTrivia).get();
    expect(first.length, 13);

    final seasonalIds = first.where((row) => row.isSeasonal).map((row) => row.id);
    expect(
      seasonalIds,
      containsAll(<String>['christmas', 'easter', 'halloween', 'thanksgiving']),
    );

    await ensureDefaultInterestsTrivia(db);
    final second = await db.select(db.interestsTrivia).get();
    expect(second.length, 13);
  });
}
