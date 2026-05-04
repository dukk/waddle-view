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
  test('construct controller without starting long loop', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.tickerScreens).insert(
          TickerScreensCompanion.insert(
            id: 's1',
            bodyText: const Value('Hi'),
          ),
        );
    final repo = DriftTickerScheduleRepository(db);
    final controller = TickerRotationController(
      repository: repo,
      evaluator: const TickerConditionEvaluator(),
      clock: FakeClock(DateTime(2026, 5, 10)),
      sleeper: FakeSleeper(),
    );
    expect(controller.isRunning, equals(false));
    expect(controller.currentLabel, equals(null));
    controller.stop();
    await db.close();
  });
}
