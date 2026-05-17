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

  final screensByConfig = <String, Set<String>>{};
  final tickersByConfig = <String, Set<String>>{};
  final overlaysByConfig = <String, Set<String>>{};
  for (final m in members) {
    switch (m.entityType) {
      case kCuratorMemberEntityScreen:
        screensByConfig
            .putIfAbsent(m.configurationId, () => {})
            .add(m.entityId);
      case kCuratorMemberEntityTicker:
        tickersByConfig
            .putIfAbsent(m.configurationId, () => {})
            .add(m.entityId);
      case kCuratorMemberEntityOverlay:
        overlaysByConfig
            .putIfAbsent(m.configurationId, () => {})
            .add(m.entityId);
    }
  }

  return [
    for (final c in configs)
      CuratorConfigurationInput(
        id: c.id,
        name: c.name,
        layer: c.layer,
        sortOrder: c.sortOrder,
        programDurationSeconds: c.programDurationSeconds,
        historyDepth: c.historyDepth,
        requireNewsPhotoForScreens: c.requireNewsPhotoForScreens,
        themeIdOverride: c.themeIdOverride,
        defaultConfig: c.defaultConfig,
        rules: rulesByConfig[c.id] ?? const [],
        screenMemberIds: screensByConfig[c.id] ?? const {},
        tickerMemberIds: tickersByConfig[c.id] ?? const {},
        overlayMemberIds: overlaysByConfig[c.id] ?? const {},
      ),
  ];
}
