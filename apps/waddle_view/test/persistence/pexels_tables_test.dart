import 'package:flutter_test/flutter_test.dart';

import '../helpers/memory_database.dart';

void main() {
  test('opened database includes media and Pexels batch tables', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('content_categories','photos','videos','pexels_fetch_batches')",
    ).get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(names, {'content_categories', 'photos', 'videos', 'pexels_fetch_batches'});

    final photoCols = await db.customSelect('PRAGMA table_info(photos)').get();
    expect(
      photoCols.map((r) => r.read<String>('name')).toList(),
      contains('data_provider'),
    );
    await db.close();
  });
}
