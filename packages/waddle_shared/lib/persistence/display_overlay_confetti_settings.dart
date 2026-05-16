import 'dart:convert';

/// Allowed `shapes` entries in `overlays.config_json` for
/// `overlay_type` `birthday_confetti`.
const Set<String> kBirthdayConfettiShapeTokens = {
  'rect',
  'circle',
  'star',
  'streamer',
  'mix',
};

final RegExp _hexColorPattern = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

/// Minimum `fall_speed` in birthday confetti `config_json` (lower = slower).
const double kBirthdayConfettiFallSpeedMin = 0.02;

/// Maximum `fall_speed` in birthday confetti `config_json`.
const double kBirthdayConfettiFallSpeedMax = 1.8;

/// Display app clamps one full vertical drift cycle to this many seconds max.
const double kBirthdayConfettiMaxCycleSeconds = 300.0;

/// Resolved schedule settings for birthday confetti (no Flutter types).
class BirthdayConfettiScheduleSettings {
  const BirthdayConfettiScheduleSettings({
    required this.shapeTokens,
    required this.colorHexes,
    required this.density,
    required this.messageIntervalSec,
    required this.fallSpeed,
    required this.opacity,
  });

  /// When [colorHexes] is empty, the display app uses theme accent colors.
  ///
  /// [fallSpeed] is a relative fall rate: **lower = slower** drift (about
  /// `5s / fallSpeed` per full vertical cycle at 1.0 baseline, capped by
  /// [kBirthdayConfettiMaxCycleSeconds]). [opacity] caps
  /// per-piece alpha (higher = more visible).
  static const BirthdayConfettiScheduleSettings defaults =
      BirthdayConfettiScheduleSettings(
        shapeTokens: <String>['mix'],
        colorHexes: <String>[],
        density: 0.36,
        messageIntervalSec: 36,
        fallSpeed: 0.14,
        opacity: 0.46,
      );

  final List<String> shapeTokens;
  final List<String> colorHexes;
  final double density;
  final int messageIntervalSec;

  /// Vertical scroll speed factor; lower values move confetti more slowly.
  final double fallSpeed;

  /// Upper bound for confetti piece alpha (roughly layer brightness).
  final double opacity;

  static BirthdayConfettiScheduleSettings parse(String configJson) {
    dynamic decoded;
    try {
      decoded = jsonDecode(configJson.trim().isEmpty ? '{}' : configJson);
    } on Object {
      return BirthdayConfettiScheduleSettings.defaults;
    }
    if (decoded is! Map) {
      return BirthdayConfettiScheduleSettings.defaults;
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
        if (kBirthdayConfettiShapeTokens.contains(t)) {
          shapes.add(t);
        }
      }
    }
    if (shapes.isEmpty) {
      shapes = List<String>.from(BirthdayConfettiScheduleSettings.defaults.shapeTokens);
    }

    final colors = <String>[];
    final rawColors = map['colors'];
    if (rawColors is List) {
      for (final e in rawColors) {
        if (e is! String) {
          continue;
        }
        final h = e.trim();
        if (_hexColorPattern.hasMatch(h)) {
          colors.add(h);
        }
      }
    }

    double density = BirthdayConfettiScheduleSettings.defaults.density;
    final rawDensity = map['density'];
    if (rawDensity is num) {
      density = rawDensity.toDouble().clamp(0.25, 0.65);
    }

    var interval = BirthdayConfettiScheduleSettings.defaults.messageIntervalSec;
    final rawInterval = map['message_interval_sec'];
    if (rawInterval is num) {
      interval = rawInterval.round().clamp(12, 90);
    }

    var fallSpeed = BirthdayConfettiScheduleSettings.defaults.fallSpeed;
    final rawFall = map['fall_speed'];
    if (rawFall is num) {
      fallSpeed = rawFall.toDouble().clamp(
        kBirthdayConfettiFallSpeedMin,
        kBirthdayConfettiFallSpeedMax,
      );
    }

    var opacity = BirthdayConfettiScheduleSettings.defaults.opacity;
    final rawOpacity = map['opacity'];
    if (rawOpacity is num) {
      opacity = rawOpacity.toDouble().clamp(0.12, 0.72);
    }

    return BirthdayConfettiScheduleSettings(
      shapeTokens: shapes,
      colorHexes: colors,
      density: density,
      messageIntervalSec: interval,
      fallSpeed: fallSpeed,
      opacity: opacity,
    );
  }
}

/// Returns `null` when [raw] is not a JSON object or violates confetti rules.
String? normalizeBirthdayConfettiSettingsJsonString(String raw) {
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
  if (!_confettiSettingsMapValid(map)) {
    return null;
  }
  final out = <String, dynamic>{};
  if (map.containsKey('shapes')) {
    final list = <String>[];
    final raw = map['shapes'];
    if (raw is List) {
      for (final e in raw) {
        if (e is String) {
          final t = e.trim().toLowerCase();
          if (kBirthdayConfettiShapeTokens.contains(t)) {
            list.add(t);
          }
        }
      }
    }
    if (list.isNotEmpty) {
      out['shapes'] = list;
    }
  }
  if (map.containsKey('colors')) {
    final list = <String>[];
    final raw = map['colors'];
    if (raw is List) {
      for (final e in raw) {
        if (e is String && _hexColorPattern.hasMatch(e.trim())) {
          list.add(e.trim());
        }
      }
    }
    if (list.isNotEmpty) {
      out['colors'] = list;
    }
  }
  if (map.containsKey('density') && map['density'] is num) {
    final d = (map['density'] as num).toDouble().clamp(0.15, 0.9);
    out['density'] = d;
  }
  if (map.containsKey('message_interval_sec') && map['message_interval_sec'] is num) {
    final s = (map['message_interval_sec'] as num).round().clamp(8, 120);
    out['message_interval_sec'] = s;
  }
  if (map.containsKey('fall_speed') && map['fall_speed'] is num) {
    final v = (map['fall_speed'] as num).toDouble().clamp(
      kBirthdayConfettiFallSpeedMin,
      kBirthdayConfettiFallSpeedMax,
    );
    out['fall_speed'] = v;
  }
  if (map.containsKey('opacity') && map['opacity'] is num) {
    final v = (map['opacity'] as num).toDouble().clamp(0.12, 0.72);
    out['opacity'] = v;
  }
  if (map.containsKey('messages') && map['messages'] is List) {
    final list = <String>[
      for (final e in map['messages'] as List)
        if (e is String && e.trim().isNotEmpty) e.trim(),
    ];
    out['messages'] = list;
  }
  return jsonEncode(out);
}

bool _confettiSettingsMapValid(Map<String, dynamic> map) {
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
        if (!kBirthdayConfettiShapeTokens.contains(t)) {
          return false;
        }
        any = true;
      }
      if (!any && raw.isNotEmpty) {
        return false;
      }
    }
  }
  if (map.containsKey('colors')) {
    final raw = map['colors'];
    if (raw != null && raw is! List) {
      return false;
    }
    if (raw is List) {
      for (final e in raw) {
        if (e is! String || !_hexColorPattern.hasMatch(e.trim())) {
          return false;
        }
      }
    }
  }
  if (map.containsKey('density') && map['density'] is! num) {
    return false;
  }
  if (map.containsKey('message_interval_sec') &&
      map['message_interval_sec'] is! num) {
    return false;
  }
  if (map.containsKey('fall_speed') && map['fall_speed'] is! num) {
    return false;
  }
  if (map.containsKey('opacity') && map['opacity'] is! num) {
    return false;
  }
  return true;
}
