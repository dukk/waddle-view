import 'dart:convert';

import '../persistence/database.dart';
import 'ticker_models.dart';

/// Pure eligibility rules; extend with new [TickerCondition.kind] values.
class TickerConditionEvaluator {
  const TickerConditionEvaluator();

  bool isEligible(DateTime nowLocal, TickerScreenBundle bundle) {
    if (!bundle.screen.enabled) {
      return false;
    }
    if (bundle.groups.isEmpty) {
      return _cooldownOk(nowLocal, bundle) && _maxShowsOk(nowLocal, bundle);
    }
    for (final g in bundle.groups) {
      if (!_groupMatches(nowLocal, bundle, g)) {
        return false;
      }
    }
    return _cooldownOk(nowLocal, bundle) && _maxShowsOk(nowLocal, bundle);
  }

  bool _groupMatches(
    DateTime nowLocal,
    TickerScreenBundle bundle,
    TickerConditionGroupBundle g,
  ) {
    final mode = g.group.matchMode.toUpperCase();
    final results = g.conditions.map((c) => _evalCondition(nowLocal, bundle, c));
    final list = results.toList();
    if (list.isEmpty) {
      return true;
    }
    if (mode == 'ANY') {
      return list.any((e) => e);
    }
    return list.every((e) => e);
  }

  bool _evalCondition(
    DateTime nowLocal,
    TickerScreenBundle bundle,
    TickerCondition c,
  ) {
    final Map<String, Object?> json =
        jsonDecode(c.paramsJson) as Map<String, Object?>? ?? {};
    switch (c.kind) {
      case 'weekday_in_set':
        final days = (json['weekdays'] as List?)?.cast<num>() ?? const <num>[];
        final wd = nowLocal.weekday; // Mon=1
        return days.any((d) => d.toInt() == wd);
      case 'local_time_between':
        final start = json['start'] as String? ?? '00:00';
        final end = json['end'] as String? ?? '23:59';
        return _timeBetween(nowLocal, start, end);
      case 'date_between':
        final a = DateTime.parse(json['start'] as String);
        final b = DateTime.parse(json['end'] as String);
        final d = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
        return !d.isBefore(a) && !d.isAfter(b);
      case 'expression_and':
        return true;
      default:
        return false;
    }
  }

  bool _timeBetween(DateTime nowLocal, String start, String end) {
    int parse(String s) {
      final p = s.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    final cur = nowLocal.hour * 60 + nowLocal.minute;
    final a = parse(start);
    final b = parse(end);
    if (a <= b) {
      return cur >= a && cur <= b;
    }
    return cur >= a || cur <= b;
  }

  bool _cooldownOk(DateTime nowLocal, TickerScreenBundle bundle) {
    final ended = bundle.runtime?.lastEndedAt;
    if (ended == null) {
      return true;
    }
    final gap = bundle.screen.minGapBeforeRepeatMs;
    final elapsed = nowLocal.millisecondsSinceEpoch - ended;
    return elapsed >= gap;
  }

  bool _maxShowsOk(DateTime nowLocal, TickerScreenBundle bundle) {
    for (final g in bundle.groups) {
      for (final c in g.conditions) {
        if (c.kind != 'max_shows_per_local_day') {
          continue;
        }
        final Map<String, Object?> json =
            jsonDecode(c.paramsJson) as Map<String, Object?>? ?? {};
        final max = (json['max'] as num?)?.toInt() ?? 0;
        if (max <= 0) {
          continue;
        }
        final key = _dayKey(nowLocal);
        if (bundle.runtime?.localDayKey == key &&
            (bundle.runtime?.showsOnLocalDay ?? 0) >= max) {
          return false;
        }
      }
    }
    return true;
  }

  String _dayKey(DateTime local) =>
      '${local.year}-${local.month}-${local.day}';
}
