import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/alerts/drift_alert_repository.dart';
import 'package:waddle_view/clock.dart';

import 'helpers/memory_database.dart';

void main() {
  test('insert dismiss watchActive', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final repo = DriftAlertRepository(db);
    final clock = FakeClock(DateTime.utc(2026, 5, 3, 12));
    final id = await repo.insertAlert(
      title: 't',
      body: 'b',
      priority: 1,
    );
    expect(id, greaterThan(0));
    await repo.dismiss(id);
    final sub = repo.watchActive(clock);
    expect(await sub.first, isNull);
    await db.close();
  });
}
