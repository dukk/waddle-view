import 'dart:convert';

import 'package:waddle_shared/curation/overlay_calendar_match.dart';
import 'package:waddle_shared/persistence/display_overlay_schedule_row.dart';

export 'package:waddle_shared/curation/overlay_calendar_match.dart'
    show nthWeekdayOccurrenceInMonth;

bool matchesCelebrationOverlay(
  DisplayOverlayScheduleRow row,
  DateTime localNow, {
  Map<String, dynamic> runtimeSignals = const {},
}) {
  final trigger = _parseOverlayTrigger(row.configJson);
  if (trigger != null) {
    final signalOk = _evaluateOverlayTrigger(trigger, runtimeSignals);
    if (trigger.calendarIgnored) {
      return signalOk;
    }
    return signalOk &&
        matchesOverlayCalendar(
          OverlayCalendarFields(
            repeatAnnually: row.repeatAnnually,
            yearExact: row.yearExact,
            startMonth: row.startMonth,
            startDay: row.startDay,
            endMonth: row.endMonth,
            endDay: row.endDay,
            nthWeekOfMonth: row.nthWeekOfMonth,
            nthWeekday: row.nthWeekday,
          ),
          localNow,
        );
  }
  return matchesOverlayCalendar(
    OverlayCalendarFields(
      repeatAnnually: row.repeatAnnually,
      yearExact: row.yearExact,
      startMonth: row.startMonth,
      startDay: row.startDay,
      endMonth: row.endMonth,
      endDay: row.endDay,
      nthWeekOfMonth: row.nthWeekOfMonth,
      nthWeekday: row.nthWeekday,
    ),
    localNow,
  );
}

class _OverlayTrigger {
  const _OverlayTrigger({
    required this.signalId,
    required this.when,
    required this.calendarIgnored,
  });

  final String signalId;
  final bool when;
  final bool calendarIgnored;
}

_OverlayTrigger? _parseOverlayTrigger(String configJson) {
  if (configJson.trim().isEmpty) {
    return null;
  }
  try {
    final v = jsonDecode(configJson);
    if (v is! Map<String, dynamic>) {
      return null;
    }
    final t = v['trigger'];
    if (t is! Map<String, dynamic>) {
      return null;
    }
    final signal = (t['signal'] as String?)?.trim() ?? '';
    if (signal.isEmpty) {
      return null;
    }
    return _OverlayTrigger(
      signalId: signal,
      when: t['when'] as bool? ?? true,
      calendarIgnored: t['calendar_ignored'] as bool? ?? false,
    );
  } on Object {
    return null;
  }
}

bool _evaluateOverlayTrigger(
  _OverlayTrigger trigger,
  Map<String, dynamic> runtimeSignals,
) {
  final v = runtimeSignals[trigger.signalId];
  final boolVal = v is bool
      ? v
      : v is Map && v['bool'] is bool
          ? v['bool'] as bool
          : false;
  return boolVal == trigger.when;
}
