import 'package:waddle_shared/curation/curator_member_op.dart';
import 'package:waddle_shared/curation/curator_schedule_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

/// Loads curator rows from [db] for [CuratorScheduleResolver].
Future<List<CuratorConfigurationInput>> loadCuratorConfigurationInputs(
  AppDatabase db,
) async {
  final configs = await db.select(db.curatorConfigurations).get();
  final rules = await db.select(db.curatorScheduleRules).get();
  final members = await db.select(db.curatorConfigurationMembers).get();

  final rulesByConfig = <String, List<CuratorScheduleRuleInput>>{};
  for (final r in rules) {
    rulesByConfig.putIfAbsent(r.configurationId, () => []).add(
      CuratorScheduleRuleInput(
        id: r.id,
        configurationId: r.configurationId,
        priority: r.priority,
        statePredicate: r.statePredicate,
        daysOfWeekMask: r.daysOfWeekMask,
        startTimeMinutes: r.startTimeMinutes,
        endTimeMinutes: r.endTimeMinutes,
        startMonth: r.startMonth,
        startDay: r.startDay,
        endMonth: r.endMonth,
        endDay: r.endDay,
        repeatAnnually: r.repeatAnnually,
        yearExact: r.yearExact,
        nthWeekOfMonth: r.nthWeekOfMonth,
        nthWeekday: r.nthWeekday,
      ),
    );
  }

  List<CuratorMemberOp> opsFor(
    String configId,
    String entityType,
  ) {
    final list = <CuratorMemberOp>[];
    for (final m in members) {
      if (m.configurationId != configId || m.entityType != entityType) {
        continue;
      }
      list.add(
        CuratorMemberOp(
          entityId: m.entityId,
          op: normalizeCuratorMemberOp(m.op),
        ),
      );
    }
    return list;
  }

  return [
    for (final c in configs)
      CuratorConfigurationInput(
        id: c.id,
        name: c.name,
        layer: c.layer,
        sortOrder: c.sortOrder,
        programDurationSeconds: c.programDurationSeconds,
        tickerProgramDurationSeconds: c.tickerProgramDurationSeconds,
        tickerPixelsPerSecond: c.tickerPixelsPerSecond,
        historyDepth: c.historyDepth,
        requireNewsPhotoForScreens: c.requireNewsPhotoForScreens,
        screensEnabled: c.screensEnabled,
        tickerEnabled: c.tickerEnabled,
        themeIdOverride: c.themeIdOverride,
        viewportReserveTopPctOverride: c.viewportReserveTopPctOverride,
        viewportReserveRightPctOverride: c.viewportReserveRightPctOverride,
        viewportReserveBottomPctOverride: c.viewportReserveBottomPctOverride,
        viewportReserveLeftPctOverride: c.viewportReserveLeftPctOverride,
        defaultConfig: c.defaultConfig,
        parentConfigurationId: c.parentConfigurationId,
        rules: rulesByConfig[c.id] ?? const [],
        screenMemberOps: opsFor(c.id, kCuratorMemberEntityScreen),
        tickerMemberOps: opsFor(c.id, kCuratorMemberEntityTicker),
        overlayMemberOps: opsFor(c.id, kCuratorMemberEntityOverlay),
      ),
  ];
}

/// Builds a map of configuration id → input for member resolution.
Map<String, CuratorConfigurationInput> curatorConfigurationInputById(
  List<CuratorConfigurationInput> inputs,
) {
  return {for (final c in inputs) c.id: c};
}
