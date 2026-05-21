import 'dart:convert';

/// Allowed `cloud_type` values in `overlays.config_json` for `cloud_drift`.
const List<String> kCloudDriftCloudTypes = <String>[
  'cirrostratus',
  'cirrus',
  'cumulus',
  'stratocumulus',
  'altostratus',
];

/// Default cloud morphology (light grey high sheet clouds).
const String kCloudDriftDefaultCloudType = 'cirrostratus';

/// Default tint for cirrostratus-style clouds.
const String kCloudDriftDefaultColorHex = '#C8CDD3';

final RegExp kCloudDriftHexColorPattern =
    RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

/// Minimum vertical/size scatter (0 = uniform band).
const double kCloudDriftScatterMin = 0.0;

/// Maximum scatter.
const double kCloudDriftScatterMax = 1.0;

/// Minimum density (fewer clouds).
const double kCloudDriftDensityMin = 0.1;

/// Maximum density.
const double kCloudDriftDensityMax = 0.9;

/// Minimum layer opacity (more transparent).
const double kCloudDriftOpacityMin = 0.08;

/// Maximum layer opacity.
const double kCloudDriftOpacityMax = 0.85;

/// Resolved schedule settings for cloud drift (no Flutter types).
class CloudDriftScheduleSettings {
  const CloudDriftScheduleSettings({
    required this.cloudType,
    required this.scatter,
    required this.density,
    required this.opacity,
    required this.colorHex,
  });

  static const CloudDriftScheduleSettings defaults = CloudDriftScheduleSettings(
    cloudType: kCloudDriftDefaultCloudType,
    scatter: 0.45,
    density: 0.35,
    opacity: 0.42,
    colorHex: kCloudDriftDefaultColorHex,
  );

  final String cloudType;
  final double scatter;
  final double density;
  final double opacity;
  final String colorHex;

  static CloudDriftScheduleSettings parse(String configJson) {
    dynamic decoded;
    try {
      decoded = jsonDecode(configJson.trim().isEmpty ? '{}' : configJson);
    } on Object {
      return CloudDriftScheduleSettings.defaults;
    }
    if (decoded is! Map) {
      return CloudDriftScheduleSettings.defaults;
    }
    final map = decoded.cast<String, dynamic>();

    var cloudType = CloudDriftScheduleSettings.defaults.cloudType;
    final rawType = map['cloud_type'];
    if (rawType is String) {
      final t = rawType.trim();
      if (kCloudDriftCloudTypes.contains(t)) {
        cloudType = t;
      }
    }

    var scatter = CloudDriftScheduleSettings.defaults.scatter;
    final rawScatter = map['scatter'];
    if (rawScatter is num) {
      scatter = rawScatter.toDouble().clamp(
        kCloudDriftScatterMin,
        kCloudDriftScatterMax,
      );
    }

    var density = CloudDriftScheduleSettings.defaults.density;
    final rawDensity = map['density'];
    if (rawDensity is num) {
      density = rawDensity.toDouble().clamp(
        kCloudDriftDensityMin,
        kCloudDriftDensityMax,
      );
    }

    var opacity = CloudDriftScheduleSettings.defaults.opacity;
    final rawOpacity = map['opacity'];
    if (rawOpacity is num) {
      opacity = rawOpacity.toDouble().clamp(
        kCloudDriftOpacityMin,
        kCloudDriftOpacityMax,
      );
    }

    var colorHex = CloudDriftScheduleSettings.defaults.colorHex;
    final rawColor = map['color'];
    if (rawColor is String) {
      final h = rawColor.trim();
      if (kCloudDriftHexColorPattern.hasMatch(h)) {
        colorHex = h;
      }
    }

    return CloudDriftScheduleSettings(
      cloudType: cloudType,
      scatter: scatter,
      density: density,
      opacity: opacity,
      colorHex: colorHex,
    );
  }
}

/// Returns `null` when [raw] is not a JSON object or violates cloud-drift rules.
String? normalizeCloudDriftSettingsJsonString(String raw) {
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
  if (!_cloudDriftSettingsMapValid(map)) {
    return null;
  }
  final out = <String, dynamic>{};
  if (map.containsKey('cloud_type') && map['cloud_type'] is String) {
    final t = (map['cloud_type'] as String).trim();
    if (kCloudDriftCloudTypes.contains(t)) {
      out['cloud_type'] = t;
    }
  }
  if (map.containsKey('scatter') && map['scatter'] is num) {
    out['scatter'] = (map['scatter'] as num).toDouble().clamp(
      kCloudDriftScatterMin,
      kCloudDriftScatterMax,
    );
  }
  if (map.containsKey('density') && map['density'] is num) {
    out['density'] = (map['density'] as num).toDouble().clamp(
      kCloudDriftDensityMin,
      kCloudDriftDensityMax,
    );
  }
  if (map.containsKey('opacity') && map['opacity'] is num) {
    out['opacity'] = (map['opacity'] as num).toDouble().clamp(
      kCloudDriftOpacityMin,
      kCloudDriftOpacityMax,
    );
  }
  if (map.containsKey('color') && map['color'] is String) {
    final h = (map['color'] as String).trim();
    if (kCloudDriftHexColorPattern.hasMatch(h)) {
      out['color'] = h;
    }
  }
  return jsonEncode(out);
}

bool _cloudDriftSettingsMapValid(Map<String, dynamic> map) {
  if (map.containsKey('cloud_type')) {
    if (map['cloud_type'] is! String) {
      return false;
    }
    final t = (map['cloud_type'] as String).trim();
    if (!kCloudDriftCloudTypes.contains(t)) {
      return false;
    }
  }
  if (map.containsKey('scatter') && map['scatter'] is! num) {
    return false;
  }
  if (map.containsKey('density') && map['density'] is! num) {
    return false;
  }
  if (map.containsKey('opacity') && map['opacity'] is! num) {
    return false;
  }
  if (map.containsKey('color')) {
    if (map['color'] is! String) {
      return false;
    }
    if (!kCloudDriftHexColorPattern.hasMatch((map['color'] as String).trim())) {
      return false;
    }
  }
  return true;
}
