import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/ticker/ticker_condition_evaluator.dart';
import 'package:waddle_view/ticker/ticker_models.dart';

void main() {
  const ev = TickerConditionEvaluator();

  TickerScreenBundle bundle({
    required List<TickerConditionGroupBundle> groups,
    TickerScreenRuntime? runtime,
  }) {
    return TickerScreenBundle(
      screen: const TickerScreen(
        id: 's',
        sortKey: 0,
        enabled: true,
        dwellMs: 1000,
        minGapBeforeRepeatMs: 0,
        contentKind: null,
        bodyText: 'x',
      ),
      groups: groups,
      runtime: runtime,
    );
  }

  test('weekday_in_set matches Saturday', () {
    final sat = DateTime(2026, 5, 2); // Saturday
    final b = bundle(
      groups: [
        TickerConditionGroupBundle(
          group: const TickerConditionGroup(
            id: 1,
            screenId: 's',
            matchMode: 'ALL',
          ),
          conditions: const [
            TickerCondition(
              id: 1,
              groupId: 1,
              kind: 'weekday_in_set',
              paramsJson: '{"weekdays":[6]}',
            ),
          ],
        ),
      ],
    );
    expect(ev.isEligible(sat, b), isTrue);
  });

  test('local_time_between overnight window', () {
    final t = DateTime(2026, 5, 2, 1, 30); // 01:30
    final b = bundle(
      groups: [
        TickerConditionGroupBundle(
          group: const TickerConditionGroup(
            id: 1,
            screenId: 's',
            matchMode: 'ALL',
          ),
          conditions: const [
            TickerCondition(
              id: 1,
              groupId: 1,
              kind: 'local_time_between',
              paramsJson: '{"start":"22:00","end":"06:00"}',
            ),
          ],
        ),
      ],
    );
    expect(ev.isEligible(t, b), isTrue);
  });

  test('disabled screen is never eligible', () {
    final b = TickerScreenBundle(
      screen: const TickerScreen(
        id: 's',
        sortKey: 0,
        enabled: false,
        dwellMs: 1000,
        minGapBeforeRepeatMs: 0,
        contentKind: null,
        bodyText: 'x',
      ),
      groups: const [],
      runtime: null,
    );
    expect(ev.isEligible(DateTime(2026, 5, 2), b), isFalse);
  });
}
