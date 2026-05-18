import 'dart:convert';

/// Minimum `opacity` in matrix rain `config_json` (lower = more see-through).
const double kMatrixRainOpacityMin = 0.08;

/// Maximum `opacity` in matrix rain `config_json`.
const double kMatrixRainOpacityMax = 0.85;

/// Minimum `fall_speed` in matrix rain `config_json` (lower = slower).
const double kMatrixRainFallSpeedMin = 0.05;

/// Maximum `fall_speed` in matrix rain `config_json`.
const double kMatrixRainFallSpeedMax = 2.0;

/// Resolved schedule settings for matrix rain (no Flutter types).
class MatrixRainScheduleSettings {
  const MatrixRainScheduleSettings({
    required this.opacity,
    required this.fallSpeed,
  });

  /// [opacity] caps glyph alpha (higher = more visible). [fallSpeed] is a
  /// relative vertical drift rate: lower values move characters more slowly.
  static const MatrixRainScheduleSettings defaults = MatrixRainScheduleSettings(
    opacity: 0.35,
    fallSpeed: 0.45,
  );

  final double opacity;
  final double fallSpeed;

  static MatrixRainScheduleSettings parse(String configJson) {
    dynamic decoded;
    try {
      decoded = jsonDecode(configJson.trim().isEmpty ? '{}' : configJson);
    } on Object {
      return MatrixRainScheduleSettings.defaults;
    }
    if (decoded is! Map) {
      return MatrixRainScheduleSettings.defaults;
    }
    final map = decoded.cast<String, dynamic>();

    var opacity = MatrixRainScheduleSettings.defaults.opacity;
    final rawOpacity = map['opacity'];
    if (rawOpacity is num) {
      opacity = rawOpacity.toDouble().clamp(
        kMatrixRainOpacityMin,
        kMatrixRainOpacityMax,
      );
    }

    var fallSpeed = MatrixRainScheduleSettings.defaults.fallSpeed;
    final rawFall = map['fall_speed'];
    if (rawFall is num) {
      fallSpeed = rawFall.toDouble().clamp(
        kMatrixRainFallSpeedMin,
        kMatrixRainFallSpeedMax,
      );
    }

    return MatrixRainScheduleSettings(opacity: opacity, fallSpeed: fallSpeed);
  }
}

/// Returns `null` when [raw] is not a JSON object or violates matrix-rain rules.
String? normalizeMatrixRainSettingsJsonString(String raw) {
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
  if (!_matrixRainSettingsMapValid(map)) {
    return null;
  }
  final out = <String, dynamic>{};
  if (map.containsKey('opacity') && map['opacity'] is num) {
    final v = (map['opacity'] as num).toDouble().clamp(
      kMatrixRainOpacityMin,
      kMatrixRainOpacityMax,
    );
    out['opacity'] = v;
  }
  if (map.containsKey('fall_speed') && map['fall_speed'] is num) {
    final v = (map['fall_speed'] as num).toDouble().clamp(
      kMatrixRainFallSpeedMin,
      kMatrixRainFallSpeedMax,
    );
    out['fall_speed'] = v;
  }
  return jsonEncode(out);
}

bool _matrixRainSettingsMapValid(Map<String, dynamic> map) {
  if (map.containsKey('opacity') && map['opacity'] is! num) {
    return false;
  }
  if (map.containsKey('fall_speed') && map['fall_speed'] is! num) {
    return false;
  }
  return true;
}
