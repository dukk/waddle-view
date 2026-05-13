import 'package:test/test.dart';

import '../helpers/memory_database.dart';

void main() {
  test('opened database has no category_icons table', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE type='table' AND name='category_icons'",
    ).get();
    expect(rows, isEmpty);
    await db.close();
  });
}
