import 'dart:convert';

import 'package:waddle_shared/persistence/display_overlay_row.dart';

bool matchesCelebrationOverlay(
  DisplayOverlayRow row,
  DateTime localNow, {
  Map<String, dynamic> runtimeSignals = const {},
}) {
  final trigger = _parseOverlayTrigger(row.configJson);
  if (trigger == null) {
    return true;
  }
  return _evaluateOverlayTrigger(trigger, runtimeSignals);
}

class _OverlayTrigger {
  const _OverlayTrigger({
    required this.signalId,
    required this.when,
  });

  final String signalId;
  final bool when;
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
