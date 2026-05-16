import 'dart:convert';

final RegExp _hexColorPattern = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

/// Resolved `config_json` for `bouncing_message` overlays (no Flutter types).
class BouncingMessageScheduleSettings {
  const BouncingMessageScheduleSettings({
    this.colorHex,
    this.fontFamily,
    required this.fontSize,
    required this.fontWeightValue,
    required this.letterSpacing,
    required this.shadow,
    required this.speed,
  });

  static const BouncingMessageScheduleSettings defaults =
      BouncingMessageScheduleSettings(
        colorHex: null,
        fontFamily: null,
        fontSize: 38,
        fontWeightValue: 700,
        letterSpacing: 0.6,
        shadow: true,
        speed: 1.0,
      );

  /// Optional `#RRGGBB` / `#AARRGGBB`; null uses theme primary in the app.
  final String? colorHex;

  /// Optional [TextStyle.fontFamily]; null uses the theme body family.
  final String? fontFamily;

  final double fontSize;
  final int fontWeightValue;
  final double letterSpacing;
  final bool shadow;

  /// Velocity multiplier (about **0.25–2.5**).
  final double speed;

  static BouncingMessageScheduleSettings parse(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw.trim().isEmpty ? '{}' : raw);
    } on Object {
      return BouncingMessageScheduleSettings.defaults;
    }
    if (decoded is! Map) {
      return BouncingMessageScheduleSettings.defaults;
    }
    final map = decoded.cast<String, dynamic>();

    String? colorHex;
    final rawColor = map['color'];
    if (rawColor is String && _hexColorPattern.hasMatch(rawColor.trim())) {
      colorHex = rawColor.trim();
    }

    String? fontFamily;
    final rawFam = map['font_family'];
    if (rawFam is String) {
      final t = rawFam.trim();
      if (t.isNotEmpty && t.length <= 120) {
        fontFamily = t;
      }
    }

    var fontSize = BouncingMessageScheduleSettings.defaults.fontSize;
    final rawSize = map['font_size'];
    if (rawSize is num) {
      fontSize = rawSize.toDouble().clamp(14.0, 96.0);
    }

    var fontWeightValue = BouncingMessageScheduleSettings.defaults.fontWeightValue;
    final rawW = map['font_weight'];
    if (rawW is num) {
      fontWeightValue = (rawW.round() ~/ 100 * 100).clamp(100, 900);
    } else if (rawW is String) {
      final v = int.tryParse(rawW.trim());
      if (v != null) {
        fontWeightValue = (v ~/ 100 * 100).clamp(100, 900);
      }
    }

    var letterSpacing = BouncingMessageScheduleSettings.defaults.letterSpacing;
    final rawLs = map['letter_spacing'];
    if (rawLs is num) {
      letterSpacing = rawLs.toDouble().clamp(-1.5, 6.0);
    }

    var shadow = BouncingMessageScheduleSettings.defaults.shadow;
    final rawShadow = map['shadow'];
    if (rawShadow is bool) {
      shadow = rawShadow;
    }

    var speed = BouncingMessageScheduleSettings.defaults.speed;
    final rawSpeed = map['speed'];
    if (rawSpeed is num) {
      speed = rawSpeed.toDouble().clamp(0.25, 2.5);
    }

    return BouncingMessageScheduleSettings(
      colorHex: colorHex,
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeightValue: fontWeightValue,
      letterSpacing: letterSpacing,
      shadow: shadow,
      speed: speed,
    );
  }
}

/// Returns `null` when [raw] is not a JSON object or violates rules.
String? normalizeBouncingMessageConfigJsonString(String raw) {
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
  if (!_bouncingMessageConfigMapValid(map)) {
    return null;
  }
  final out = <String, dynamic>{};
  if (map.containsKey('color')) {
    final c = map['color'];
    if (c is String && _hexColorPattern.hasMatch(c.trim())) {
      out['color'] = c.trim();
    }
  }
  if (map.containsKey('font_family')) {
    final f = map['font_family'];
    if (f is String) {
      final t = f.trim();
      if (t.isNotEmpty && t.length <= 120) {
        out['font_family'] = t;
      }
    }
  }
  if (map.containsKey('font_size') && map['font_size'] is num) {
    out['font_size'] = (map['font_size'] as num).toDouble().clamp(14.0, 96.0);
  }
  if (map.containsKey('font_weight') && map['font_weight'] is num) {
    final w = (map['font_weight'] as num).round();
    out['font_weight'] = (w ~/ 100 * 100).clamp(100, 900);
  } else if (map.containsKey('font_weight') && map['font_weight'] is String) {
    final v = int.tryParse((map['font_weight'] as String).trim());
    if (v != null) {
      out['font_weight'] = (v ~/ 100 * 100).clamp(100, 900);
    }
  }
  if (map.containsKey('letter_spacing') && map['letter_spacing'] is num) {
    out['letter_spacing'] =
        (map['letter_spacing'] as num).toDouble().clamp(-1.5, 6.0);
  }
  if (map.containsKey('shadow') && map['shadow'] is bool) {
    out['shadow'] = map['shadow'] as bool;
  }
  if (map.containsKey('speed') && map['speed'] is num) {
    out['speed'] = (map['speed'] as num).toDouble().clamp(0.25, 2.5);
  }
  if (map.containsKey('messages')) {
    final raw = map['messages'];
    if (raw is List) {
      final list = <String>[
        for (final e in raw)
          if (e is String && e.trim().isNotEmpty) e.trim(),
      ];
      out['messages'] = list;
    }
  }
  return jsonEncode(out);
}

bool _bouncingMessageConfigMapValid(Map<String, dynamic> map) {
  for (final key in map.keys) {
    if (!const {
      'color',
      'font_family',
      'font_size',
      'font_weight',
      'letter_spacing',
      'shadow',
      'speed',
      'messages',
    }.contains(key)) {
      return false;
    }
  }
  if (map.containsKey('color') && map['color'] is! String) {
    return false;
  }
  if (map.containsKey('color') &&
      map['color'] is String &&
      !_hexColorPattern.hasMatch((map['color'] as String).trim())) {
    return false;
  }
  if (map.containsKey('font_family') && map['font_family'] is! String) {
    return false;
  }
  if (map.containsKey('font_size') && map['font_size'] is! num) {
    return false;
  }
  if (map.containsKey('font_weight') &&
      map['font_weight'] is! num &&
      map['font_weight'] is! String) {
    return false;
  }
  if (map.containsKey('letter_spacing') && map['letter_spacing'] is! num) {
    return false;
  }
  if (map.containsKey('shadow') && map['shadow'] is! bool) {
    return false;
  }
  if (map.containsKey('speed') && map['speed'] is! num) {
    return false;
  }
  if (map.containsKey('messages')) {
    final raw = map['messages'];
    if (raw is! List) {
      return false;
    }
    for (final e in raw) {
      if (e is! String || e.trim().isEmpty) {
        return false;
      }
    }
  }
  return true;
}
