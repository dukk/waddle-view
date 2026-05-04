import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/ticker/ticker_condition_evaluator.dart';
import 'package:waddle_view/ticker/ticker_models.dart';

void main() {
  const ev = TickerConditionEvaluator();

  TickerScreenBundle mk({
    required List<TickerConditionGroupBundle> groups,
    TickerScreenRuntime? runtime,
    bool enabled = true,
  }) {
    return TickerScreenBundle(
      screen: TickerScreen(
        id: 's',
        sortKey: 0,
        enabled: enabled,
        dwellMs: 1000,
        minGapBeforeRepeatMs: 1000,
        contentKind: null,
        bodyText: 't',
      ),
      groups: groups,
      runtime: runtime,
    );
  }

  test('date_between', () {
    final d = DateTime(2026, 5, 10);
    final b = mk(
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
              kind: 'date_between',
              paramsJson: '{"start":"2026-05-01","end":"2026-05-31"}',
            ),
          ],
        ),
      ],
    );
    expect(ev.isEligible(d, b), isTrue);
  });

  test('max_shows_per_local_day blocks when at cap', () {
    final d = DateTime(2026, 5, 10, 12);
    final b = mk(
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
              kind: 'max_shows_per_local_day',
              paramsJson: '{"max":1}',
            ),
          ],
        ),
      ],
      runtime: const TickerScreenRuntime(
        screenId: 's',
        lastStartedAt: null,
        lastEndedAt: null,
        showsOnLocalDay: 1,
        localDayKey: '2026-5-10',
      ),
    );
    expect(ev.isEligible(d, b), isFalse);
  });

  test('ANY group with one true passes', () {
    final d = DateTime(2026, 5, 2); // Saturday
    final b = mk(
      groups: [
        TickerConditionGroupBundle(
          group: const TickerConditionGroup(
            id: 1,
            screenId: 's',
            matchMode: 'ANY',
          ),
          conditions: const [
            TickerCondition(
              id: 1,
              groupId: 1,
              kind: 'weekday_in_set',
              paramsJson: '{"weekdays":[6]}',
            ),
            TickerCondition(
              id: 2,
              groupId: 1,
              kind: 'weekday_in_set',
              paramsJson: '{"weekdays":[1]}',
            ),
          ],
        ),
      ],
    );
    expect(ev.isEligible(d, b), isTrue);
  });
}
