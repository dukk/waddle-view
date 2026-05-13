import 'package:test/test.dart';

import '../helpers/memory_database.dart';

void main() {
  test('fresh database creates ticker_definitions table', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='ticker_definitions'",
    ).get();
    expect(rows.length, 1);
    await db.close();
  });
}
