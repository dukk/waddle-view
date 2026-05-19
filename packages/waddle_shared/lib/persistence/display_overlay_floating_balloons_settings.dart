import 'dart:convert';
import 'dart:math' as math;

/// Stock palette for `floating_balloons` when `colors` is omitted.
const List<String> kFloatingBalloonsDefaultColorHexes = <String>[
  '#E53935',
  '#FFEB3B',
  '#00BCD4',
  '#E91E63',
  '#43A047',
  '#8E24AA',
];

final RegExp _hexColorPattern = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

/// Minimum seconds between balloon spawns.
const int kFloatingBalloonsSpawnIntervalSecMin = 1;

/// Maximum seconds between balloon spawns.
const int kFloatingBalloonsSpawnIntervalSecMax = 120;

/// Minimum vertical rise speed in logical pixels per second.
const double kFloatingBalloonsRiseSpeedPxPerSecMin = 30;

/// Maximum vertical rise speed in logical pixels per second.
const double kFloatingBalloonsRiseSpeedPxPerSecMax = 500;

/// Minimum base balloon size as a fraction of viewport shortest side.
const double kFloatingBalloonsBalloonScaleMin = 0.04;

/// Maximum base balloon size as a fraction of viewport shortest side.
const double kFloatingBalloonsBalloonScaleMax = 0.20;

/// Maximum per-unit random size multiplier spread (0 = fixed size).
const double kFloatingBalloonsScaleJitterMax = 1.0;

/// Minimum concurrent balloon units (single balloon or cluster).
const int kFloatingBalloonsMaxActiveMin = 1;

/// Maximum concurrent balloon units.
const int kFloatingBalloonsMaxActiveMax = 12;

/// Cluster sizes used when spawning a multi-balloon bunch.
const List<int> kFloatingBalloonsClusterSizes = <int>[3, 5, 8];

/// Resolved `config_json` for `floating_balloons` overlays (no Flutter types).
class FloatingBalloonsScheduleSettings {
  const FloatingBalloonsScheduleSettings({
    required this.colorHexes,
    required this.spawnIntervalSec,
    required this.riseSpeed,
    required this.maxActive,
    required this.clusterChance,
    required this.balloonScale,
    required this.scaleJitter,
    required this.opacity,
  });

  static const FloatingBalloonsScheduleSettings defaults =
      FloatingBalloonsScheduleSettings(
        colorHexes: <String>[],
        spawnIntervalSec: 22,
        riseSpeed: 85,
        maxActive: 6,
        clusterChance: 0.4,
        balloonScale: 0.09,
        scaleJitter: 0.25,
        opacity: 0.92,
      );

  final List<String> colorHexes;
  final int spawnIntervalSec;
  final double riseSpeed;
  final int maxActive;
  final double clusterChance;
  final double balloonScale;
  final double scaleJitter;
  final double opacity;

  /// Configured colors, or [kFloatingBalloonsDefaultColorHexes] when empty.
  List<String> get effectiveColorHexes =>
      colorHexes.isNotEmpty ? colorHexes : kFloatingBalloonsDefaultColorHexes;

  static FloatingBalloonsScheduleSettings parse(String configJson) {
    dynamic decoded;
    try {
      decoded = jsonDecode(configJson.trim().isEmpty ? '{}' : configJson);
    } on Object {
      return FloatingBalloonsScheduleSettings.defaults;
    }
    if (decoded is! Map) {
      return FloatingBalloonsScheduleSettings.defaults;
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

    var spawnIntervalSec =
        FloatingBalloonsScheduleSettings.defaults.spawnIntervalSec;
    final rawInterval = map['spawn_interval_sec'];
    if (rawInterval is num) {
      spawnIntervalSec = rawInterval.round().clamp(
        kFloatingBalloonsSpawnIntervalSecMin,
        kFloatingBalloonsSpawnIntervalSecMax,
      );
    }

    var riseSpeed = FloatingBalloonsScheduleSettings.defaults.riseSpeed;
    final rawRise = map['rise_speed'];
    if (rawRise is num) {
      riseSpeed = rawRise.toDouble().clamp(
        kFloatingBalloonsRiseSpeedPxPerSecMin,
        kFloatingBalloonsRiseSpeedPxPerSecMax,
      );
    }

    var maxActive = FloatingBalloonsScheduleSettings.defaults.maxActive;
    final rawMax = map['max_active'];
    if (rawMax is num) {
      maxActive = rawMax.round().clamp(
        kFloatingBalloonsMaxActiveMin,
        kFloatingBalloonsMaxActiveMax,
      );
    }

    var clusterChance =
        FloatingBalloonsScheduleSettings.defaults.clusterChance;
    final rawCluster = map['cluster_chance'];
    if (rawCluster is num) {
      clusterChance = rawCluster.toDouble().clamp(0, 1);
    }

    var balloonScale =
        FloatingBalloonsScheduleSettings.defaults.balloonScale;
    final rawScale = map['balloon_scale'];
    if (rawScale is num) {
      balloonScale = rawScale.toDouble().clamp(
        kFloatingBalloonsBalloonScaleMin,
        kFloatingBalloonsBalloonScaleMax,
      );
    }

    var scaleJitter =
        FloatingBalloonsScheduleSettings.defaults.scaleJitter;
    final rawJitter = map['scale_jitter'];
    if (rawJitter is num) {
      scaleJitter = rawJitter.toDouble().clamp(0, kFloatingBalloonsScaleJitterMax);
    }

    var opacity = FloatingBalloonsScheduleSettings.defaults.opacity;
    final rawOpacity = map['opacity'];
    if (rawOpacity is num) {
      opacity = rawOpacity.toDouble().clamp(0.2, 1.0);
    }

    return FloatingBalloonsScheduleSettings(
      colorHexes: colors,
      spawnIntervalSec: spawnIntervalSec,
      riseSpeed: riseSpeed,
      maxActive: maxActive,
      clusterChance: clusterChance,
      balloonScale: balloonScale,
      scaleJitter: scaleJitter,
      opacity: opacity,
    );
  }
}

/// Picks distinct hex colors for [count] balloons when the palette allows it.
List<String> pickFloatingBalloonClusterColors(
  List<String> palette,
  int count,
  math.Random rng,
) {
  if (palette.isEmpty || count <= 0) {
    return <String>[];
  }
  final shuffled = List<String>.from(palette)..shuffle(rng);
  return List<String>.generate(
    count,
    (i) => shuffled[i % shuffled.length],
  );
}

/// Returns cluster size: `1` for a single balloon, otherwise one of
/// [kFloatingBalloonsClusterSizes].
int pickFloatingBalloonClusterSize(
  math.Random rng, {
  required double clusterChance,
}) {
  if (rng.nextDouble() >= clusterChance) {
    return 1;
  }
  return kFloatingBalloonsClusterSizes[
    rng.nextInt(kFloatingBalloonsClusterSizes.length)
  ];
}

/// Relative (x, y) offsets for balloons in a cluster; values are fractions of
/// balloon diameter from the cluster center.
class BalloonClusterOffset {
  const BalloonClusterOffset(this.dx, this.dy);

  final double dx;
  final double dy;
}

/// Randomized layout for [count] balloons: base shape plus rotation, spread,
/// and per-balloon jitter so clusters do not repeat the same silhouette.
List<BalloonClusterOffset> randomFloatingBalloonClusterLayoutOffsets(
  int count,
  math.Random rng,
) {
  final base = floatingBalloonClusterLayoutOffsets(count);
  if (base.isEmpty) {
    return base;
  }
  final angle = rng.nextDouble() * math.pi * 2;
  final cosA = math.cos(angle);
  final sinA = math.sin(angle);
  final spread = 0.82 + rng.nextDouble() * 0.38;
  const jitter = 0.26;

  return [
    for (final b in base)
      () {
        final dx = b.dx * spread + (rng.nextDouble() * 2 - 1) * jitter;
        final dy = b.dy * spread + (rng.nextDouble() * 2 - 1) * jitter;
        return BalloonClusterOffset(
          dx * cosA - dy * sinA,
          dx * sinA + dy * cosA,
        );
      }(),
  ];
}

/// Layout offsets for [count] balloons in a cluster.
List<BalloonClusterOffset> floatingBalloonClusterLayoutOffsets(int count) {
  switch (count) {
    case 1:
      return const [BalloonClusterOffset(0, 0)];
    case 3:
      return const [
        BalloonClusterOffset(0, -0.22),
        BalloonClusterOffset(-0.4, 0.28),
        BalloonClusterOffset(0.4, 0.28),
      ];
    case 5:
      return const [
        BalloonClusterOffset(0, -0.3),
        BalloonClusterOffset(-0.42, -0.05),
        BalloonClusterOffset(0.42, -0.05),
        BalloonClusterOffset(-0.38, 0.32),
        BalloonClusterOffset(0.38, 0.32),
      ];
    case 8:
      return const [
        BalloonClusterOffset(0, -0.38),
        BalloonClusterOffset(-0.38, -0.22),
        BalloonClusterOffset(0.38, -0.22),
        BalloonClusterOffset(-0.48, 0.08),
        BalloonClusterOffset(0.48, 0.08),
        BalloonClusterOffset(-0.38, 0.32),
        BalloonClusterOffset(0.38, 0.32),
        BalloonClusterOffset(0, 0.38),
      ];
    default:
      return List<BalloonClusterOffset>.generate(
        count,
        (i) {
          final angle = i / count * math.pi * 2;
          return BalloonClusterOffset(
            math.cos(angle) * 0.4,
            math.sin(angle) * 0.35,
          );
        },
      );
  }
}

/// Returns `null` when [raw] is not a JSON object or violates rules.
String? normalizeFloatingBalloonsConfigJsonString(String raw) {
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
  if (!_floatingBalloonsConfigMapValid(map)) {
    return null;
  }
  final out = <String, dynamic>{};
  if (map.containsKey('colors') && map['colors'] is List) {
    final list = <String>[
      for (final e in map['colors'] as List)
        if (e is String && _hexColorPattern.hasMatch(e.trim())) e.trim(),
    ];
    if (list.isNotEmpty) {
      out['colors'] = list;
    }
  }
  if (map.containsKey('spawn_interval_sec') &&
      map['spawn_interval_sec'] is num) {
    out['spawn_interval_sec'] = (map['spawn_interval_sec'] as num).round().clamp(
      kFloatingBalloonsSpawnIntervalSecMin,
      kFloatingBalloonsSpawnIntervalSecMax,
    );
  }
  if (map.containsKey('rise_speed') && map['rise_speed'] is num) {
    out['rise_speed'] = (map['rise_speed'] as num).toDouble().clamp(
      kFloatingBalloonsRiseSpeedPxPerSecMin,
      kFloatingBalloonsRiseSpeedPxPerSecMax,
    );
  }
  if (map.containsKey('max_active') && map['max_active'] is num) {
    out['max_active'] = (map['max_active'] as num).round().clamp(
      kFloatingBalloonsMaxActiveMin,
      kFloatingBalloonsMaxActiveMax,
    );
  }
  if (map.containsKey('cluster_chance') && map['cluster_chance'] is num) {
    out['cluster_chance'] = (map['cluster_chance'] as num).toDouble().clamp(
      0,
      1,
    );
  }
  if (map.containsKey('balloon_scale') && map['balloon_scale'] is num) {
    out['balloon_scale'] = (map['balloon_scale'] as num).toDouble().clamp(
      kFloatingBalloonsBalloonScaleMin,
      kFloatingBalloonsBalloonScaleMax,
    );
  }
  if (map.containsKey('scale_jitter') && map['scale_jitter'] is num) {
    out['scale_jitter'] = (map['scale_jitter'] as num).toDouble().clamp(
      0,
      kFloatingBalloonsScaleJitterMax,
    );
  }
  if (map.containsKey('opacity') && map['opacity'] is num) {
    out['opacity'] = (map['opacity'] as num).toDouble().clamp(0.2, 1.0);
  }
  return jsonEncode(out);
}

bool _floatingBalloonsConfigMapValid(Map<String, dynamic> map) {
  for (final key in map.keys) {
    if (!const {
      'colors',
      'spawn_interval_sec',
      'rise_speed',
      'max_active',
      'cluster_chance',
      'balloon_scale',
      'scale_jitter',
      'opacity',
    }.contains(key)) {
      return false;
    }
  }
  if (map.containsKey('colors')) {
    final raw = map['colors'];
    if (raw is! List) {
      return false;
    }
    for (final e in raw) {
      if (e is! String || !_hexColorPattern.hasMatch(e.trim())) {
        return false;
      }
    }
  }
  if (map.containsKey('spawn_interval_sec') &&
      map['spawn_interval_sec'] is! num) {
    return false;
  }
  if (map.containsKey('rise_speed') && map['rise_speed'] is! num) {
    return false;
  }
  if (map.containsKey('max_active') && map['max_active'] is! num) {
    return false;
  }
  if (map.containsKey('cluster_chance') && map['cluster_chance'] is! num) {
    return false;
  }
  if (map.containsKey('balloon_scale') && map['balloon_scale'] is! num) {
    return false;
  }
  if (map.containsKey('scale_jitter') && map['scale_jitter'] is! num) {
    return false;
  }
  if (map.containsKey('opacity') && map['opacity'] is! num) {
    return false;
  }
  return true;
}
