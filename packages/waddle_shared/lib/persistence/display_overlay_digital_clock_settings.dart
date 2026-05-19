import 'dart:convert';

import 'display_overlay_clock_placement.dart';

/// Resolved digital clock overlay settings from overlay `config_json`.
class DigitalClockOverlaySettings {
  const DigitalClockOverlaySettings({
    required this.placement,
    required this.hour24,
    required this.showSeconds,
  });

  static const DigitalClockOverlaySettings defaults =
      DigitalClockOverlaySettings(
    placement: ClockOverlayPlacement.defaults,
    hour24: false,
    showSeconds: false,
  );

  final ClockOverlayPlacement placement;
  final bool hour24;
  final bool showSeconds;

  Map<String, dynamic> toJson() => {
        ...placement.toJson(),
        if (hour24) 'hour24': true,
        if (showSeconds) 'showSeconds': true,
      };

  Map<String, dynamic> clockConfigMap() => {
        if (hour24) 'hour24': true,
        if (showSeconds) 'showSeconds': true,
      };

  static DigitalClockOverlaySettings parse(String configJson) {
    if (configJson.trim().isEmpty) {
      return defaults;
    }
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is Map<String, dynamic>) {
        return parseMap(decoded);
      }
      if (decoded is Map) {
        return parseMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      /* fall through */
    }
    return defaults;
  }

  static DigitalClockOverlaySettings parseMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    return DigitalClockOverlaySettings(
      placement: ClockOverlayPlacement.parseMap(raw),
      hour24: raw['hour24'] == true,
      showSeconds: raw['showSeconds'] == true,
    );
  }
}

/// Returns `null` when [raw] is not a JSON object or violates digital-clock rules.
String? normalizeDigitalClockOverlayConfigJsonString(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '{}') {
    return '{}';
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on Object {
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  final map = decoded.cast<String, dynamic>();
  map.remove('messages');
  map.remove('message_interval_sec');
  map.remove('enabled');
  if (!_digitalClockOverlayConfigMapValid(map)) {
    return null;
  }
  final settings = DigitalClockOverlaySettings.parseMap(map);
  return jsonEncode(settings.toJson());
}

bool _digitalClockOverlayConfigMapValid(Map<String, dynamic> map) {
  if (!validateClockOverlayPlacementMap(map)) {
    return false;
  }
  if (map.containsKey('hour24') && map['hour24'] is! bool) {
    return false;
  }
  if (map.containsKey('showSeconds') && map['showSeconds'] is! bool) {
    return false;
  }
  return true;
}
