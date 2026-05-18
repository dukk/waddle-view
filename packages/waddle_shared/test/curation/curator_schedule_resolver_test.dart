import 'package:test/test.dart';
import 'package:waddle_shared/curation/curator_runtime_state.dart';
import 'package:waddle_shared/curation/curator_schedule_resolver.dart';
import 'package:waddle_shared/curation/curator_state_predicates.dart';
import 'package:waddle_shared/persistence/tables.dart';

CuratorConfigurationInput _config({
  required String id,
  required String layer,
  int sortOrder = 0,
  bool defaultConfig = false,
  List<CuratorScheduleRuleInput> rules = const [],
  Set<String> screens = const {},
  Set<String> overlays = const {},
}) {
  return CuratorConfigurationInput(
    id: id,
    name: id,
    layer: layer,
    sortOrder: sortOrder,
    programDurationSeconds: 180,
    historyDepth: 5,
    requireNewsPhotoForScreens: true,
    tickerEnabled: true,
    defaultConfig: defaultConfig,
    rules: rules,
    screenMemberIds: screens,
    tickerMemberIds: const {},
    overlayMemberIds: overlays,
  );
}

void main() {
  test('bootstrap exclusive blocks base and enhancements', () {
    final configs = [
      _config(
        id: 'bootstrap',
        layer: kCuratorLayerExclusive,
        rules: [
          CuratorScheduleRuleInput(
            id: 'r1',
            configurationId: 'bootstrap',
            priority: 10000,
            statePredicate: kCuratorPredicateDisplayNotAdopted,
            repeatAnnually: true,
          ),
        ],
        screens: {'admin_setup'},
      ),
      _config(
        id: 'evening',
        layer: kCuratorLayerBase,
        defaultConfig: true,
        rules: [
          CuratorScheduleRuleInput(
            id: 'e1',
            configurationId: 'evening',
            priority: 10,
            startTimeMinutes: 18 * 60,
            endTimeMinutes: 22 * 60,
            daysOfWeekMask: 0x7F,
            repeatAnnually: true,
          ),
        ],
        screens: {'jokes'},
      ),
    ];
    final sel = CuratorScheduleResolver.resolve(
      localNow: DateTime(2026, 5, 13, 19),
      state: const CuratorRuntimeState(displayAdopted: false),
      configurations: configs,
    );
    expect(sel.exclusive, isNotNull);
    expect(sel.exclusive!.configuration.id, 'bootstrap');
    expect(sel.base, isNull);
    expect(sel.enhancements, isEmpty);
  });

  test('May 13 evening stacks birthday enhancement on base', () {
    final configs = [
      _config(
        id: 'evening',
        layer: kCuratorLayerBase,
        rules: [
          CuratorScheduleRuleInput(
            id: 'e1',
            configurationId: 'evening',
            priority: 10,
            startTimeMinutes: 18 * 60,
            endTimeMinutes: 22 * 60,
            daysOfWeekMask: 0x7F,
            repeatAnnually: true,
          ),
        ],
        screens: {'jokes'},
      ),
      _config(
        id: 'waddle_birthday',
        layer: kCuratorLayerEnhancement,
        rules: [
          CuratorScheduleRuleInput(
            id: 'b1',
            configurationId: 'waddle_birthday',
            priority: 1000,
            startMonth: 5,
            startDay: 13,
            repeatAnnually: true,
          ),
        ],
        overlays: {'overlay_confetti'},
      ),
    ];
    final sel = CuratorScheduleResolver.resolve(
      localNow: DateTime(2026, 5, 13, 19),
      state: const CuratorRuntimeState(displayAdopted: true),
      configurations: configs,
    );
    expect(sel.exclusive, isNull);
    expect(sel.base!.configuration.id, 'evening');
    expect(sel.enhancements, hasLength(1));
    expect(sel.enhancements.first.configuration.id, 'waddle_birthday');
    expect(sel.effectiveOverlayMemberIds, contains('overlay_confetti'));
  });
}
