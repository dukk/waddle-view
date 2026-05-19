import 'package:test/test.dart';

import '../helpers/memory_database.dart';

void main() {
  test('fresh database creates ticker_tapes table', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='ticker_tapes'",
    ).get();
    expect(rows.length, 1);
    final cols = await db.customSelect(
      'PRAGMA table_info(ticker_tapes);',
    ).get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names.contains('label'), isTrue);
    expect(names.contains('ticker_type'), isTrue);
    expect(names.contains('config_json'), isTrue);
    expect(names.contains('config_json_schema'), isFalse);
    expect(names.contains('example_config_json'), isFalse);
    await db.close();
  });
}
