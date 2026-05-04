import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/ticker/drift_ticker_schedule_repository.dart';

import 'helpers/memory_database.dart';

void main() {
  test('onShowStart and onShowEnd update runtime', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.tickerScreens).insert(
          TickerScreensCompanion.insert(id: 'z'),
        );
    final repo = DriftTickerScheduleRepository(db);
    final t0 = DateTime(2026, 6, 1, 8);
    await repo.onShowStart('z', t0);
    await repo.onShowEnd('z', DateTime(2026, 6, 1, 9));
    final row =
        await (db.select(db.tickerScreenRuntimes)
              ..where((r) => r.screenId.equals('z')))
            .getSingle();
    expect(row.lastStartedAt, isNotNull);
    expect(row.lastEndedAt, isNotNull);
    await db.close();
  });
}
