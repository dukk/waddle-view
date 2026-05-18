import 'dart:convert';

final RegExp kEdgeGlowHexColorPattern =
    RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

/// Default glow color (alarm-friendly red).
const String kEdgeGlowDefaultColorHex = '#FF3B30';

/// Minimum `intensity` in edge glow `config_json`.
const double kEdgeGlowIntensityMin = 0.08;

/// Maximum `intensity` in edge glow `config_json`.
const double kEdgeGlowIntensityMax = 0.95;

/// Minimum `pulse_speed` in edge glow `config_json` (lower = slower pulse).
const double kEdgeGlowPulseSpeedMin = 0.05;

/// Maximum `pulse_speed` in edge glow `config_json`.
const double kEdgeGlowPulseSpeedMax = 3.0;

/// Resolved schedule settings for edge glow (no Flutter types).
class EdgeGlowScheduleSettings {
  const EdgeGlowScheduleSettings({
    required this.colorHex,
    required this.intensity,
    required this.pulseSpeed,
  });

  /// [intensity] caps peak edge alpha (higher = brighter glow).
  /// [pulseSpeed] is a relative pulse rate: higher values fade in/out faster.
  static const EdgeGlowScheduleSettings defaults = EdgeGlowScheduleSettings(
    colorHex: kEdgeGlowDefaultColorHex,
    intensity: 0.65,
    pulseSpeed: 1.0,
  );

  final String colorHex;
  final double intensity;
  final double pulseSpeed;

  static EdgeGlowScheduleSettings parse(String configJson) {
    dynamic decoded;
    try {
      decoded = jsonDecode(configJson.trim().isEmpty ? '{}' : configJson);
    } on Object {
      return EdgeGlowScheduleSettings.defaults;
    }
    if (decoded is! Map) {
      return EdgeGlowScheduleSettings.defaults;
    }
    final map = decoded.cast<String, dynamic>();

    var colorHex = EdgeGlowScheduleSettings.defaults.colorHex;
    final rawColor = map['color'];
    if (rawColor is String) {
      final h = rawColor.trim();
      if (kEdgeGlowHexColorPattern.hasMatch(h)) {
        colorHex = h;
      }
    }

    var intensity = EdgeGlowScheduleSettings.defaults.intensity;
    final rawIntensity = map['intensity'];
    if (rawIntensity is num) {
      intensity = rawIntensity.toDouble().clamp(
        kEdgeGlowIntensityMin,
        kEdgeGlowIntensityMax,
      );
    }

    var pulseSpeed = EdgeGlowScheduleSettings.defaults.pulseSpeed;
    final rawPulse = map['pulse_speed'];
    if (rawPulse is num) {
      pulseSpeed = rawPulse.toDouble().clamp(
        kEdgeGlowPulseSpeedMin,
        kEdgeGlowPulseSpeedMax,
      );
    }

    return EdgeGlowScheduleSettings(
      colorHex: colorHex,
      intensity: intensity,
      pulseSpeed: pulseSpeed,
    );
  }
}

/// Returns `null` when [raw] is not a JSON object or violates edge-glow rules.
String? normalizeEdgeGlowSettingsJsonString(String raw) {
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
  if (!_edgeGlowSettingsMapValid(map)) {
    return null;
  }
  final out = <String, dynamic>{};
  if (map.containsKey('color') && map['color'] is String) {
    final h = (map['color'] as String).trim();
    if (kEdgeGlowHexColorPattern.hasMatch(h)) {
      out['color'] = h;
    }
  }
  if (map.containsKey('intensity') && map['intensity'] is num) {
    final v = (map['intensity'] as num).toDouble().clamp(
      kEdgeGlowIntensityMin,
      kEdgeGlowIntensityMax,
    );
    out['intensity'] = v;
  }
  if (map.containsKey('pulse_speed') && map['pulse_speed'] is num) {
    final v = (map['pulse_speed'] as num).toDouble().clamp(
      kEdgeGlowPulseSpeedMin,
      kEdgeGlowPulseSpeedMax,
    );
    out['pulse_speed'] = v;
  }
  return jsonEncode(out);
}

bool _edgeGlowSettingsMapValid(Map<String, dynamic> map) {
  if (map.containsKey('color') &&
      (map['color'] is! String ||
          !kEdgeGlowHexColorPattern.hasMatch((map['color'] as String).trim()))) {
    return false;
  }
  if (map.containsKey('intensity') && map['intensity'] is! num) {
    return false;
  }
  if (map.containsKey('pulse_speed') && map['pulse_speed'] is! num) {
    return false;
  }
  return true;
}
