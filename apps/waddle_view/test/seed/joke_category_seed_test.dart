import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/seed/joke_category_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('ensureDefaultJokeCategories inserts all rows once', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);
    final first = await db.select(db.jokeCategories).get();
    expect(first.length, 9);
    await ensureDefaultJokeCategories(db);
    final second = await db.select(db.jokeCategories).get();
    expect(second.length, 9);
  });
}
