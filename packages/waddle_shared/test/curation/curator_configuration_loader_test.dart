import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';
import 'package:waddle_shared/curation/curator_configuration_loader.dart';
import 'package:waddle_shared/curation/curator_schedule_resolver.dart';
import 'package:waddle_shared/curation/curator_runtime_state.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/initial_seed.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test('effectiveCuratorMemberIdsForConfig unions ancestor members', () {
    final merged = effectiveCuratorMemberIdsForConfig(
      configId: 'morning',
      ownByConfig: {
        'default': {'clock_digital'},
        'morning': {'news', 'weather'},
      },
      parentById: {
        'default': null,
        'morning': 'default',
      },
    );
    expect(merged, {'news', 'weather', 'clock_digital'});
  });

  test('effectiveCuratorMemberIdsForConfig detects parent cycles', () {
    expect(
      () => effectiveCuratorMemberIdsForConfig(
        configId: 'a',
        ownByConfig: const {},
        parentById: {'a': 'b', 'b': 'a'},
      ),
      throwsStateError,
    );
  });

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
    expect(defaultConfig.screenMemberIds, kDefaultBaseCuratorScreenMemberIds.toSet());
    expect(defaultConfig.tickerMemberIds, kDefaultBaseCuratorTickerMemberIds.toSet());

    final bootstrap = inputs.singleWhere((c) => c.id == 'bootstrap');
    expect(bootstrap.layer, kCuratorLayerExclusive);
    expect(bootstrap.rules, isNotEmpty);
    expect(bootstrap.screenMemberIds, isNotEmpty);

    final evening = inputs.singleWhere((c) => c.id == 'evening');
    expect(evening.layer, kCuratorLayerBase);
    expect(evening.tickerEnabled, isTrue);
    expect(evening.tickerProgramDurationSeconds, isNull);
    expect(evening.tickerPixelsPerSecond, isNull);
    expect(evening.screenMemberIds, contains('clock_digital'));
    expect(evening.screenMemberIds, contains('jokes'));
    expect(evening.tickerMemberIds, containsAll(['ticker_time', 'ticker_custom']));

    final morning = inputs.singleWhere((c) => c.id == 'morning');
    expect(morning.screenMemberIds, containsAll(['news', 'clock_digital']));
    expect(morning.tickerMemberIds, containsAll(['ticker_time', 'ticker_news']));

    await db.close();
  });

  test('morning schedule resolution includes default screen members', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureInitialSeed(db);

    final inputs = await loadCuratorConfigurationInputs(db);
    final sel = CuratorScheduleResolver.resolve(
      localNow: DateTime(2026, 5, 13, 8),
      state: const CuratorRuntimeState(displayAdopted: true),
      configurations: inputs,
    );
    expect(sel.base!.configuration.id, 'morning');
    expect(sel.effectiveScreenMemberIds, contains('clock_digital'));
    expect(sel.effectiveScreenMemberIds, contains('news'));

    await db.close();
  });

  test('loadCuratorConfigurationInputs reads parent_configuration_id from db', () async {
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
    expect(child.screenMemberIds, {'clock_digital', 'news'});

    await db.close();
  });
}
