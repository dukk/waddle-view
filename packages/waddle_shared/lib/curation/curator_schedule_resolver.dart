import 'curator_runtime_state.dart';
import 'curator_state_predicates.dart';
import 'overlay_calendar_match.dart';
import 'package:waddle_shared/persistence/tables.dart';

/// Input row for [CuratorScheduleResolver.resolve].
class CuratorConfigurationInput {
  const CuratorConfigurationInput({
    required this.id,
    required this.name,
    required this.layer,
    required this.sortOrder,
    required this.programDurationSeconds,
    required this.historyDepth,
    required this.requireNewsPhotoForScreens,
    this.themeIdOverride,
    required this.defaultConfig,
    required this.rules,
    required this.screenMemberIds,
    required this.tickerMemberIds,
    required this.overlayMemberIds,
  });

  final String id;
  final String name;
  final String layer;
  final int sortOrder;
  final int programDurationSeconds;
  final int historyDepth;
  final bool requireNewsPhotoForScreens;
  final String? themeIdOverride;
  final bool defaultConfig;
  final List<CuratorScheduleRuleInput> rules;
  final Set<String> screenMemberIds;
  final Set<String> tickerMemberIds;
  final Set<String> overlayMemberIds;
}

class CuratorScheduleRuleInput {
  const CuratorScheduleRuleInput({
    required this.id,
    required this.configurationId,
    required this.priority,
    this.statePredicate,
    this.daysOfWeekMask,
    this.startTimeMinutes,
    this.endTimeMinutes,
    this.startMonth,
    this.startDay,
    this.endMonth,
    this.endDay,
    required this.repeatAnnually,
    this.yearExact,
    this.nthWeekOfMonth,
    this.nthWeekday,
  });

  final String id;
  final String configurationId;
  final int priority;
  final String? statePredicate;
  final int? daysOfWeekMask;
  final int? startTimeMinutes;
  final int? endTimeMinutes;
  final int? startMonth;
  final int? startDay;
  final int? endMonth;
  final int? endDay;
  final bool repeatAnnually;
  final int? yearExact;
  final int? nthWeekOfMonth;
  final int? nthWeekday;
}

class ResolvedCuratorConfiguration {
  const ResolvedCuratorConfiguration({
    required this.configuration,
    required this.matchedRuleId,
    required this.matchReason,
  });

  final CuratorConfigurationInput configuration;
  final String matchedRuleId;
  final String matchReason;
}

class ResolvedCuratorSelection {
  const ResolvedCuratorSelection({
    this.exclusive,
    required this.base,
    this.enhancements = const [],
  });

  final ResolvedCuratorConfiguration? exclusive;
  final ResolvedCuratorConfiguration? base;
  final List<ResolvedCuratorConfiguration> enhancements;

  ResolvedCuratorConfiguration get primary =>
      exclusive ?? base!;

  Set<String> get effectiveOverlayMemberIds {
    final ids = <String>{};
    if (exclusive != null) {
      ids.addAll(exclusive!.configuration.overlayMemberIds);
      return ids;
    }
    if (base != null) {
      ids.addAll(base!.configuration.overlayMemberIds);
    }
    for (final e in enhancements) {
      ids.addAll(e.configuration.overlayMemberIds);
    }
    return ids;
  }
}

class CuratorScheduleResolver {
  CuratorScheduleResolver._();

  static ResolvedCuratorSelection resolve({
    required DateTime localNow,
    required CuratorRuntimeState state,
    required List<CuratorConfigurationInput> configurations,
  }) {
    final matching = <_MatchedRule>[];
    for (final config in configurations) {
      for (final rule in config.rules) {
        if (!_ruleMatches(rule, localNow, state)) {
          continue;
        }
        matching.add(
          _MatchedRule(
            config: config,
            rule: rule,
            specificity: _ruleSpecificity(rule),
          ),
        );
      }
    }

    final exclusiveRules = matching
        .where((m) => m.config.layer == kCuratorLayerExclusive)
        .toList();
    if (exclusiveRules.isNotEmpty) {
      final winner = _pickWinner(exclusiveRules);
      return ResolvedCuratorSelection(
        exclusive: _toResolved(winner),
        base: null,
        enhancements: const [],
      );
    }

    final baseRules =
        matching.where((m) => m.config.layer == kCuratorLayerBase).toList();
    ResolvedCuratorConfiguration? baseResolved;
    if (baseRules.isNotEmpty) {
      baseResolved = _toResolved(_pickWinner(baseRules));
    } else {
      final fallback = configurations
          .where(
            (c) => c.layer == kCuratorLayerBase && c.defaultConfig,
          )
          .toList();
      if (fallback.isEmpty) {
        throw StateError('No matching base curator and no default_config row');
      }
      fallback.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final config = fallback.first;
      baseResolved = ResolvedCuratorConfiguration(
        configuration: config,
        matchedRuleId: '',
        matchReason: 'default_config',
      );
    }

    final enhancementRules =
        matching
            .where((m) => m.config.layer == kCuratorLayerEnhancement)
            .toList();
    final byConfig = <String, _MatchedRule>{};
    for (final m in enhancementRules) {
      final existing = byConfig[m.config.id];
      if (existing == null || _compareMatched(m, existing) < 0) {
        byConfig[m.config.id] = m;
      }
    }
    final enhancements =
        byConfig.values.map(_toResolved).toList()
          ..sort(
            (a, b) => b.configuration.sortOrder.compareTo(
              a.configuration.sortOrder,
            ),
          );

    return ResolvedCuratorSelection(
      base: baseResolved,
      enhancements: enhancements,
    );
  }

  static bool _ruleMatches(
    CuratorScheduleRuleInput rule,
    DateTime localNow,
    CuratorRuntimeState state,
  ) {
    final pred = rule.statePredicate?.trim();
    if (pred != null && pred.isNotEmpty) {
      if (!isKnownCuratorStatePredicate(pred)) {
        return false;
      }
      if (!evaluateCuratorStatePredicate(pred, state)) {
        return false;
      }
    }

    final hasCal = ruleHasCalendarOrTimeConstraints(
      daysOfWeekMask: rule.daysOfWeekMask,
      startTimeMinutes: rule.startTimeMinutes,
      endTimeMinutes: rule.endTimeMinutes,
      startMonth: rule.startMonth,
      startDay: rule.startDay,
      nthWeekOfMonth: rule.nthWeekOfMonth,
    );

    if (!hasCal) {
      return true;
    }

    if (!matchesDaysOfWeekMask(rule.daysOfWeekMask, localNow)) {
      return false;
    }
    if (!matchesTimeWindowMinutes(
      startMinutes: rule.startTimeMinutes,
      endMinutes: rule.endTimeMinutes,
      localNow: localNow,
    )) {
      return false;
    }

    if (rule.nthWeekOfMonth != null ||
        (rule.startMonth != null && rule.startDay != null)) {
      final sm = rule.startMonth ?? 1;
      final sd = rule.startDay ?? 1;
      return matchesOverlayCalendar(
        OverlayCalendarFields(
          repeatAnnually: rule.repeatAnnually,
          yearExact: rule.yearExact,
          startMonth: sm,
          startDay: sd,
          endMonth: rule.endMonth,
          endDay: rule.endDay,
          nthWeekOfMonth: rule.nthWeekOfMonth,
          nthWeekday: rule.nthWeekday,
        ),
        localNow,
      );
    }

    return true;
  }

  static int _ruleSpecificity(CuratorScheduleRuleInput rule) {
    var score = 0;
    final pred = rule.statePredicate?.trim();
    if (pred != null && pred.isNotEmpty) {
      score += 100;
    }
    if (rule.nthWeekOfMonth != null) {
      score += 80;
    }
    if (rule.startMonth != null && rule.startDay != null) {
      score += 60;
    }
    if (!daysOfWeekMaskIsUnrestricted(rule.daysOfWeekMask)) {
      score += 40;
    }
    if (rule.startTimeMinutes != null || rule.endTimeMinutes != null) {
      score += 20;
    }
    return score;
  }

  static int _compareMatched(_MatchedRule a, _MatchedRule b) {
    final p = b.rule.priority.compareTo(a.rule.priority);
    if (p != 0) {
      return p;
    }
    final s = b.specificity.compareTo(a.specificity);
    if (s != 0) {
      return s;
    }
    return a.config.sortOrder.compareTo(b.config.sortOrder);
  }

  static _MatchedRule _pickWinner(List<_MatchedRule> rules) {
    rules.sort(_compareMatched);
    return rules.first;
  }

  static ResolvedCuratorConfiguration _toResolved(_MatchedRule m) {
    return ResolvedCuratorConfiguration(
      configuration: m.config,
      matchedRuleId: m.rule.id,
      matchReason: m.specificity > 0 ? 'rule_match' : 'state_or_open',
    );
  }
}

class _MatchedRule {
  const _MatchedRule({
    required this.config,
    required this.rule,
    required this.specificity,
  });

  final CuratorConfigurationInput config;
  final CuratorScheduleRuleInput rule;
  final int specificity;
}
