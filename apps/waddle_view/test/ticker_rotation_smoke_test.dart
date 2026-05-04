import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/clock.dart';
import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/sleeper.dart';
import 'package:waddle_view/ticker/drift_ticker_schedule_repository.dart';
import 'package:waddle_view/ticker/ticker_condition_evaluator.dart';
import 'package:waddle_view/ticker/ticker_rotation_controller.dart';

import 'helpers/memory_database.dart';

void main() {
  test('eligible screen runs dwell and onShowEnd', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.tickerScreens).insert(
          TickerScreensCompanion.insert(
            id: 's',
            dwellMs: const Value(1),
            bodyText: const Value('tick'),
          ),
        );
    final repo = DriftTickerScheduleRepository(db);
    final c = TickerRotationController(
      repository: repo,
      evaluator: const TickerConditionEvaluator(),
      clock: FakeClock(DateTime(2026, 5, 10)),
      sleeper: SystemSleeper(),
    );
    final f = c.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    c.stop();
    await f.timeout(const Duration(seconds: 2));
    expect(c.currentLabel, isNot(equals(null)));
    await db.close();
  });
}
