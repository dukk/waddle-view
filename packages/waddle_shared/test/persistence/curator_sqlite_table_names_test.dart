import 'package:test/test.dart';

import '../helpers/memory_database.dart';

void main() {
  test('fresh database uses curator_categories and curator_rejected_terms', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('curator_categories','curator_rejected_terms',"
      "'content_categories','reject_terms')",
    ).get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names.contains('curator_categories'), isTrue);
    expect(names.contains('curator_rejected_terms'), isTrue);
    expect(names.contains('content_categories'), isFalse);
    expect(names.contains('reject_terms'), isFalse);
    await db.close();
  });
}
