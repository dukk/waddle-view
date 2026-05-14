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
    final cols = await db.customSelect(
      'PRAGMA table_info(ticker_definitions);',
    ).get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names.contains('config_json_schema'), isTrue);
    expect(names.contains('example_config_json'), isTrue);
    await db.close();
  });
}
