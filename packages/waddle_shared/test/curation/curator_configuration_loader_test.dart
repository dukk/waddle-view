import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';
import 'package:waddle_shared/curation/curator_configuration_loader.dart';
import 'package:waddle_shared/curation/curator_member_op.dart';
import 'package:waddle_shared/curation/curator_runtime_state.dart';
import 'package:waddle_shared/curation/curator_schedule_resolver.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/initial_seed.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

Set<String> _addIds(List<CuratorMemberOp> ops) =>
    ops.where((o) => o.isAdd).map((o) => o.entityId).toSet();

void main() {
  test('loadCuratorConfigurationInputs maps seeded configs members and rules', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);

    final inputs = await loadCuratorConfigurationInputs(db);
    expect(inputs.isNotEmpty, isTrue);

    final defaultConfig = inputs.singleWhere(
      (c) => c.id == kDefaultBaseCuratorConfigurationId,
    );
    expect(defaultConfig.layer, kCuratorLayerBase);
    expect(defaultConfig.rules, isEmpty);
    expect(
      _addIds(defaultConfig.screenMemberOps),
      kDefaultBaseCuratorScreenMemberIds.toSet(),
    );
    expect(
      _addIds(defaultConfig.tickerMemberOps),
      kDefaultBaseCuratorTickerMemberIds.toSet(),
    );

    final bootstrap = inputs.singleWhere((c) => c.id == 'bootstrap');
    expect(bootstrap.layer, kCuratorLayerExclusive);
    expect(bootstrap.rules, isNotEmpty);
    expect(_addIds(bootstrap.screenMemberOps), isNotEmpty);

    final evening = inputs.singleWhere((c) => c.id == 'evening');
    expect(evening.layer, kCuratorLayerBase);
    expect(evening.tickerEnabled, isTrue);
    expect(evening.tickerProgramDurationSeconds, isNull);
    expect(evening.tickerPixelsPerSecond, isNull);
    expect(_addIds(evening.screenMemberOps), contains('jokes'));
    expect(_addIds(evening.screenMemberOps), isNot(contains('clock_digital')));
    expect(_addIds(evening.tickerMemberOps), contains('ticker_custom'));

    final morning = inputs.singleWhere((c) => c.id == 'morning');
    expect(_addIds(morning.screenMemberOps), contains('news'));
    expect(_addIds(morning.screenMemberOps), isNot(contains('clock_digital')));

    final weekday = inputs.singleWhere((c) => c.id == 'weekday');
    expect(
      weekday.screenMemberOps.any(
        (o) => o.entityId == 'photo' && o.op == kCuratorMemberOpRemove,
      ),
      isTrue,
    );

    await db.close();
  });

  test('morning schedule resolution includes default screen members', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);

    final inputs = await loadCuratorConfigurationInputs(db);
    final byId = curatorConfigurationInputById(inputs);
    final raw = CuratorScheduleResolver.resolve(
      localNow: DateTime(2026, 5, 13, 8),
      state: const CuratorRuntimeState(displayAdopted: true),
      configurations: inputs,
    );
    final sel = ResolvedCuratorSelection(
      exclusive: raw.exclusive,
      base: raw.base,
      enhancements: raw.enhancements,
      configById: byId,
    );
    expect(sel.base!.configuration.id, 'morning');
    expect(sel.effectiveScreenMemberIds, contains('clock_digital'));
    expect(sel.effectiveScreenMemberIds, contains('news'));

    await db.close();
  });

  test('loadCuratorConfigurationInputs reads own member ops only', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);

    await db.into(db.curatorConfigurations).insert(
          CuratorConfigurationsCompanion.insert(
            id: 'parent_base',
            name: 'Parent',
            layer: kCuratorLayerBase,
          ),
        );
    await db.into(db.curatorConfigurations).insert(
          CuratorConfigurationsCompanion.insert(
            id: 'child_base',
            name: 'Child',
            layer: kCuratorLayerBase,
            parentConfigurationId: const Value('parent_base'),
          ),
        );
    await db.into(db.curatorConfigurationMembers).insert(
          CuratorConfigurationMembersCompanion.insert(
            configurationId: 'parent_base',
            entityType: kCuratorMemberEntityScreen,
            entityId: 'clock_digital',
          ),
        );
    await db.into(db.curatorConfigurationMembers).insert(
          CuratorConfigurationMembersCompanion.insert(
            configurationId: 'child_base',
            entityType: kCuratorMemberEntityScreen,
            entityId: 'news',
          ),
        );

    final inputs = await loadCuratorConfigurationInputs(db);
    final child = inputs.singleWhere((c) => c.id == 'child_base');
    expect(_addIds(child.screenMemberOps), {'news'});

    final byId = curatorConfigurationInputById(inputs);
    final sel = ResolvedCuratorSelection(
      base: ResolvedCuratorConfiguration(
        configuration: child,
        matchedRuleId: '',
        matchReason: 'test',
      ),
      configById: byId,
    );
    expect(
      sel.effectiveScreenMemberIds,
      containsAll(['clock_digital', 'news']),
    );

    await db.close();
  });
}
