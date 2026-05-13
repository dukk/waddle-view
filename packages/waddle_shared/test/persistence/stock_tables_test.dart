import 'package:test/test.dart';

import '../helpers/memory_database.dart';

void main() {
  test('opened database includes stock_symbols and stock_quotes tables', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('stock_symbols','stock_quotes')",
    ).get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(names, {'stock_symbols', 'stock_quotes'});

    final symCols =
        await db.customSelect('PRAGMA table_info(stock_symbols)').get();
    final symColNames =
        symCols.map((r) => r.read<String>('name')).toSet();
    expect(symColNames, containsAll({'id', 'symbol', 'display_name', 'enabled'}));

    final qCols =
        await db.customSelect('PRAGMA table_info(stock_quotes)').get();
    final qColNames = qCols.map((r) => r.read<String>('name')).toSet();
    expect(
      qColNames,
      containsAll({
        'symbol_id',
        'current_price',
        'change_amount',
        'percent_change',
        'high_of_day',
        'low_of_day',
        'open_price',
        'previous_close',
        'quoted_at_ms',
        'observed_at_ms',
      }),
    );
    await db.close();
  });
}
