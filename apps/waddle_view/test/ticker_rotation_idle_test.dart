import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/clock.dart';
import 'package:waddle_view/ticker/ticker_condition_evaluator.dart';
import 'package:waddle_view/ticker/ticker_models.dart';
import 'package:waddle_view/ticker/ticker_rotation_controller.dart';
import 'package:waddle_view/ticker/ticker_schedule_repository.dart';

import 'helpers/callback_sleeper.dart';

class _EmptyTickerRepo implements TickerScheduleRepository {
  @override
  Future<List<TickerScreenBundle>> loadBundles() async => const [];

  @override
  Future<void> onShowEnd(String screenId, DateTime nowLocal) async {}

  @override
  Future<void> onShowStart(String screenId, DateTime nowLocal) async {}
}

void main() {
  test('rotation exits idle loop when sleeper stops controller', () async {
    late TickerRotationController c;
    var sleeps = 0;
    c = TickerRotationController(
      repository: _EmptyTickerRepo(),
      evaluator: const TickerConditionEvaluator(),
      clock: FakeClock(DateTime(2026, 5, 10)),
      sleeper: CallbackSleeper(() {
        sleeps++;
        if (sleeps >= 2) {
          c.stop();
        }
      }),
    );
    await c.start();
    expect(sleeps, greaterThanOrEqualTo(2));
  });
}
