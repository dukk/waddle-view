import 'dart:convert';

/// Stock festive palette for `birthday_confetti` when `colors` is omitted.
const List<String> kBirthdayConfettiDefaultColorHexes = <String>[
  '#E53935',
  '#FFEB3B',
  '#00BCD4',
  '#E91E63',
];

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
    required this.colorHexes,
    required this.density,
    required this.fallSpeed,
    required this.opacity,
  });

  /// When [colorHexes] is empty, the display uses [kBirthdayConfettiDefaultColorHexes].
  ///
  /// [fallSpeed] is a relative fall rate: **lower = slower** drift (about
  /// `5s / fallSpeed` per full vertical cycle at 1.0 baseline, capped by
  /// [kBirthdayConfettiMaxCycleSeconds]). [opacity] caps
  /// per-piece alpha (higher = more visible).
  static const BirthdayConfettiScheduleSettings defaults =
      BirthdayConfettiScheduleSettings(
        colorHexes: <String>[],
        density: 0.36,
        fallSpeed: 0.14,
        opacity: 0.46,
      );

  final List<String> colorHexes;
  final double density;

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
      colorHexes: colors,
      density: density,
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
  map.remove('messages');
  map.remove('message_interval_sec');
  map.remove('shapes');
  if (!_confettiSettingsMapValid(map)) {
    return null;
  }
  final out = <String, dynamic>{};
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
  return jsonEncode(out);
}

bool _confettiSettingsMapValid(Map<String, dynamic> map) {
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
  if (map.containsKey('fall_speed') && map['fall_speed'] is! num) {
    return false;
  }
  if (map.containsKey('opacity') && map['opacity'] is! num) {
    return false;
  }
  return true;
}
