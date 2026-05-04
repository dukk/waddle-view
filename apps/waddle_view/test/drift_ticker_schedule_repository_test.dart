import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/ticker/drift_ticker_schedule_repository.dart';

import 'helpers/memory_database.dart';

void main() {
  test('loadBundles orders by sortKey', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.tickerScreens).insert(
          TickerScreensCompanion.insert(
            id: 'b',
            sortKey: const Value(2),
            bodyText: const Value('B'),
          ),
        );
    await db.into(db.tickerScreens).insert(
          TickerScreensCompanion.insert(
            id: 'a',
            sortKey: const Value(1),
            bodyText: const Value('A'),
          ),
        );
    final repo = DriftTickerScheduleRepository(db);
    final bundles = await repo.loadBundles();
    expect(bundles.map((e) => e.screen.id).toList(), ['a', 'b']);
    await db.close();
  });
}
