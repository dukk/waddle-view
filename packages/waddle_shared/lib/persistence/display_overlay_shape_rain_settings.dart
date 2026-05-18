import 'dart:convert';

/// Allowed `shapes` entries in `overlays.config_json` for `overlay_type` `shape_rain`.
const Set<String> kShapeRainShapeTokens = {
  'heart',
  'raindrop',
  'cat',
  'dog',
  'mix',
};

/// Resolved schedule settings for shape rain (no Flutter types).
class ShapeRainScheduleSettings {
  const ShapeRainScheduleSettings({required this.shapeTokens});

  static const ShapeRainScheduleSettings defaults = ShapeRainScheduleSettings(
    shapeTokens: <String>['heart', 'mix'],
  );

  final List<String> shapeTokens;

  static ShapeRainScheduleSettings parse(String configJson) {
    dynamic decoded;
    try {
      decoded = jsonDecode(configJson.trim().isEmpty ? '{}' : configJson);
    } on Object {
      return ShapeRainScheduleSettings.defaults;
    }
    if (decoded is! Map) {
      return ShapeRainScheduleSettings.defaults;
    }
    final map = decoded.cast<String, dynamic>();

    var shapes = <String>[];
    final rawShapes = map['shapes'];
    if (rawShapes is List) {
      for (final e in rawShapes) {
        if (e is! String) {
          continue;
        }
        final t = e.trim().toLowerCase();
        if (kShapeRainShapeTokens.contains(t)) {
          shapes.add(t);
        }
      }
    }
    if (shapes.isEmpty) {
      shapes = List<String>.from(ShapeRainScheduleSettings.defaults.shapeTokens);
    }

    return ShapeRainScheduleSettings(shapeTokens: shapes);
  }
}

/// Returns `null` when [raw] is not a JSON object or violates shape-rain rules.
String? normalizeShapeRainSettingsJsonString(String raw) {
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
  if (!_shapeRainSettingsMapValid(map)) {
    return null;
  }
  final out = <String, dynamic>{};
  if (map.containsKey('shapes')) {
    final list = <String>[];
    final rawShapes = map['shapes'];
    if (rawShapes is List) {
      for (final e in rawShapes) {
        if (e is String) {
          final t = e.trim().toLowerCase();
          if (kShapeRainShapeTokens.contains(t)) {
            list.add(t);
          }
        }
      }
    }
    if (list.isNotEmpty) {
      out['shapes'] = list;
    }
  }
  return jsonEncode(out);
}

bool _shapeRainSettingsMapValid(Map<String, dynamic> map) {
  if (map.containsKey('shapes')) {
    final raw = map['shapes'];
    if (raw != null && raw is! List) {
      return false;
    }
    if (raw is List) {
      var any = false;
      for (final e in raw) {
        if (e is! String) {
          return false;
        }
        final t = e.trim().toLowerCase();
        if (t.isEmpty) {
          return false;
        }
        if (!kShapeRainShapeTokens.contains(t)) {
          return false;
        }
        any = true;
      }
      if (!any && raw.isNotEmpty) {
        return false;
      }
    }
  }
  return true;
}
