import 'package:test/test.dart';
import 'package:waddle_shared/curation/curator_member_op.dart';
import 'package:waddle_shared/curation/curator_member_resolver.dart';
import 'package:waddle_shared/curation/curator_schedule_resolver.dart';
import 'package:waddle_shared/persistence/tables.dart';

CuratorConfigurationInput _config({
  required String id,
  required String layer,
  int sortOrder = 0,
  String? parentConfigurationId,
  List<CuratorMemberOp> screenOps = const [],
  List<CuratorMemberOp> tickerOps = const [],
  List<CuratorMemberOp> overlayOps = const [],
}) {
  return CuratorConfigurationInput(
    id: id,
    name: id,
    layer: layer,
    sortOrder: sortOrder,
    programDurationSeconds: 180,
    historyDepth: 5,
    requireNewsPhotoForScreens: true,
    screensEnabled: true,
    tickerEnabled: true,
    defaultConfig: false,
    parentConfigurationId: parentConfigurationId,
    rules: const [],
    screenMemberOps: screenOps,
    tickerMemberOps: tickerOps,
    overlayMemberOps: overlayOps,
  );
}

CuratorMemberOp _add(String id) =>
    CuratorMemberOp(entityId: id, op: kCuratorMemberOpAdd);

CuratorMemberOp _remove(String id) =>
    CuratorMemberOp(entityId: id, op: kCuratorMemberOpRemove);

void main() {
  test('higher sort_order remove wins over lower add', () {
    final defaultCfg = _config(
      id: 'default',
      layer: kCuratorLayerBase,
      sortOrder: 5,
      screenOps: [_add('clock_digital')],
    );
    final weekday = _config(
      id: 'weekday',
      layer: kCuratorLayerEnhancement,
      sortOrder: 10,
      screenOps: [_remove('photo')],
    );
    final morning = _config(
      id: 'morning',
      layer: kCuratorLayerBase,
      sortOrder: 110,
      parentConfigurationId: 'default',
      screenOps: [_add('news'), _add('photo')],
    );
    final byId = {
      'default': defaultCfg,
      'weekday': weekday,
      'morning': morning,
    };
    final selection = ResolvedCuratorSelection(
      base: ResolvedCuratorConfiguration(
        configuration: morning,
        matchedRuleId: 'r',
        matchReason: 'test',
      ),
      enhancements: [
        ResolvedCuratorConfiguration(
          configuration: weekday,
          matchedRuleId: 'w',
          matchReason: 'test',
        ),
      ],
      configById: byId,
    );
    final screens = resolveEffectiveMemberIds(
      selection: selection,
      configById: byId,
      entityType: kCuratorMemberEntityScreen,
    );
    expect(screens, containsAll(['clock_digital', 'news']));
    expect(screens, isNot(contains('photo')));
  });

  test('ancestor ops apply before child base ops', () {
    final parent = _config(
      id: 'parent',
      layer: kCuratorLayerBase,
      sortOrder: 5,
      screenOps: [_add('clock_digital')],
    );
    final child = _config(
      id: 'child',
      layer: kCuratorLayerBase,
      sortOrder: 110,
      parentConfigurationId: 'parent',
      screenOps: [_add('news')],
    );
    final byId = {'parent': parent, 'child': child};
    final selection = ResolvedCuratorSelection(
      base: ResolvedCuratorConfiguration(
        configuration: child,
        matchedRuleId: 'r',
        matchReason: 'test',
      ),
      configById: byId,
    );
    expect(
      resolveEffectiveMemberIds(
        selection: selection,
        configById: byId,
        entityType: kCuratorMemberEntityScreen,
      ),
      {'clock_digital', 'news'},
    );
  });

  test('exclusive uses only exclusive ops', () {
    final bootstrap = _config(
      id: 'bootstrap',
      layer: kCuratorLayerExclusive,
      screenOps: [_add('admin_setup')],
    );
    final party = _config(
      id: 'party',
      layer: kCuratorLayerEnhancement,
      screenOps: [_add('photos')],
    );
    final byId = {'bootstrap': bootstrap, 'party': party};
    final selection = ResolvedCuratorSelection(
      exclusive: ResolvedCuratorConfiguration(
        configuration: bootstrap,
        matchedRuleId: 'r',
        matchReason: 'test',
      ),
      configById: byId,
    );
    expect(
      resolveEffectiveMemberIds(
        selection: selection,
        configById: byId,
        entityType: kCuratorMemberEntityScreen,
      ),
      {'admin_setup'},
    );
  });
}
