import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/seed/tables/interests_jokes_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('ensureDefaultInterestsJokes inserts all rows once', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultInterestsJokes(db);
    final first = await db.select(db.interestsJokes).get();
    expect(first.length, 9);
    await ensureDefaultInterestsJokes(db);
    final second = await db.select(db.interestsJokes).get();
    expect(second.length, 9);
  });
}
