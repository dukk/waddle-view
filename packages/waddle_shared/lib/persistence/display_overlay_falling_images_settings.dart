import 'dart:convert';

/// Blob keys for overlay uploads must use this prefix.
const String kOverlayBlobKeyPrefix = 'overlay/';

/// Minimum seconds between falling-image spawns.
const int kFallingImagesDropIntervalSecMin = 5;

/// Maximum seconds between falling-image spawns.
const int kFallingImagesDropIntervalSecMax = 180;

/// Minimum vertical speed in logical pixels per second.
const double kFallingImagesFallSpeedPxPerSecMin = 30;

/// Maximum vertical speed in logical pixels per second.
const double kFallingImagesFallSpeedPxPerSecMax = 800;

/// Default vertical speed in logical pixels per second.
const double kFallingImagesFallSpeedPxPerSecDefault = 130;

/// Legacy `fall_speed` values at or below this were screen-heights per second.
const double kFallingImagesLegacyFallSpeedMax = 1.0;

/// Reference viewport height used when converting legacy screen-height speeds.
const double kFallingImagesLegacyFallSpeedRefHeightPx = 1080;

/// Resolves stored `fall_speed` to pixels per second (migrates legacy fractions).
double resolveFallingImagesFallSpeedPxPerSec(num raw) {
  var v = raw.toDouble();
  if (v <= kFallingImagesLegacyFallSpeedMax) {
    v *= kFallingImagesLegacyFallSpeedRefHeightPx;
  }
  return v.clamp(
    kFallingImagesFallSpeedPxPerSecMin,
    kFallingImagesFallSpeedPxPerSecMax,
  );
}

/// Minimum base image size as a fraction of viewport shortest side.
const double kFallingImagesImageScaleMin = 0.04;

/// Maximum base image size as a fraction of viewport shortest side.
const double kFallingImagesImageScaleMax = 0.70;

/// Maximum per-sprite random size multiplier spread (0 = fixed size).
const double kFallingImagesScaleJitterMax = 1.0;

/// Minimum rendered sprite edge length in logical pixels.
const double kFallingImagesSpriteSizePxMin = 48.0;

/// Maximum rendered sprite edge length in logical pixels.
const double kFallingImagesSpriteSizePxMax = 440.0;

final RegExp overlayBlobKeyPattern = RegExp(r'^overlay/[a-z0-9][a-z0-9_/.-]*$');

bool isValidOverlayBlobKey(String key) => overlayBlobKeyPattern.hasMatch(key.trim());

/// Resolved `config_json` for `falling_images` overlays (no Flutter types).
class FallingImagesScheduleSettings {
  const FallingImagesScheduleSettings({
    required this.imageBlobKeys,
    required this.dropIntervalSec,
    required this.fallSpeed,
    required this.imageScale,
    required this.scaleJitter,
  });

  static const FallingImagesScheduleSettings defaults =
      FallingImagesScheduleSettings(
        imageBlobKeys: <String>[],
        dropIntervalSec: 45,
        fallSpeed: kFallingImagesFallSpeedPxPerSecDefault,
        imageScale: 0.12,
        scaleJitter: 0.33,
      );

  final List<String> imageBlobKeys;

  /// Average seconds between occasional image drops.
  final int dropIntervalSec;

  /// Vertical speed in logical pixels per second.
  final double fallSpeed;

  /// Base sprite size as a fraction of viewport shortest side.
  final double imageScale;

  /// Per-sprite random size spread (0 = fixed size at [imageScale]).
  final double scaleJitter;

  static FallingImagesScheduleSettings parse(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw.trim().isEmpty ? '{}' : raw);
    } on Object {
      return FallingImagesScheduleSettings.defaults;
    }
    if (decoded is! Map) {
      return FallingImagesScheduleSettings.defaults;
    }
    final map = decoded.cast<String, dynamic>();

    final keys = <String>[];
    final rawKeys = map['image_blob_keys'];
    if (rawKeys is List) {
      for (final e in rawKeys) {
        if (e is! String) {
          continue;
        }
        final t = e.trim();
        if (isValidOverlayBlobKey(t)) {
          keys.add(t);
        }
      }
    }

    var dropIntervalSec = FallingImagesScheduleSettings.defaults.dropIntervalSec;
    final rawInterval = map['drop_interval_sec'];
    if (rawInterval is num) {
      dropIntervalSec = rawInterval.round().clamp(
        kFallingImagesDropIntervalSecMin,
        kFallingImagesDropIntervalSecMax,
      );
    }

    var fallSpeed = FallingImagesScheduleSettings.defaults.fallSpeed;
    final rawSpeed = map['fall_speed'];
    if (rawSpeed is num) {
      fallSpeed = resolveFallingImagesFallSpeedPxPerSec(rawSpeed);
    }

    var imageScale = FallingImagesScheduleSettings.defaults.imageScale;
    final rawImageScale = map['image_scale'];
    if (rawImageScale is num) {
      imageScale = rawImageScale.toDouble().clamp(
        kFallingImagesImageScaleMin,
        kFallingImagesImageScaleMax,
      );
    }

    var scaleJitter = FallingImagesScheduleSettings.defaults.scaleJitter;
    final rawScaleJitter = map['scale_jitter'];
    if (rawScaleJitter is num) {
      scaleJitter = rawScaleJitter.toDouble().clamp(0, kFallingImagesScaleJitterMax);
    }

    return FallingImagesScheduleSettings(
      imageBlobKeys: keys,
      dropIntervalSec: dropIntervalSec,
      fallSpeed: fallSpeed,
      imageScale: imageScale,
      scaleJitter: scaleJitter,
    );
  }
}

/// Returns `null` when [raw] is not a JSON object or violates rules.
String? normalizeFallingImagesConfigJsonString(String raw) {
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
  if (!_fallingImagesConfigMapValid(map)) {
    return null;
  }
  final out = <String, dynamic>{};
  if (map.containsKey('image_blob_keys') && map['image_blob_keys'] is List) {
    final list = <String>[
      for (final e in map['image_blob_keys'] as List)
        if (e is String && isValidOverlayBlobKey(e)) e.trim(),
    ];
    out['image_blob_keys'] = list;
  }
  if (map.containsKey('drop_interval_sec') && map['drop_interval_sec'] is num) {
    out['drop_interval_sec'] = (map['drop_interval_sec'] as num).round().clamp(
      kFallingImagesDropIntervalSecMin,
      kFallingImagesDropIntervalSecMax,
    );
  }
  if (map.containsKey('fall_speed') && map['fall_speed'] is num) {
    out['fall_speed'] = resolveFallingImagesFallSpeedPxPerSec(
      map['fall_speed'] as num,
    );
  }
  if (map.containsKey('image_scale') && map['image_scale'] is num) {
    out['image_scale'] = (map['image_scale'] as num).toDouble().clamp(
      kFallingImagesImageScaleMin,
      kFallingImagesImageScaleMax,
    );
  }
  if (map.containsKey('scale_jitter') && map['scale_jitter'] is num) {
    out['scale_jitter'] = (map['scale_jitter'] as num).toDouble().clamp(
      0,
      kFallingImagesScaleJitterMax,
    );
  }
  return jsonEncode(out);
}

bool _fallingImagesConfigMapValid(Map<String, dynamic> map) {
  for (final key in map.keys) {
    if (!const {
      'image_blob_keys',
      'drop_interval_sec',
      'fall_speed',
      'image_scale',
      'scale_jitter',
    }.contains(key)) {
      return false;
    }
  }
  if (map.containsKey('image_blob_keys')) {
    final raw = map['image_blob_keys'];
    if (raw is! List) {
      return false;
    }
    for (final e in raw) {
      if (e is! String || !isValidOverlayBlobKey(e)) {
        return false;
      }
    }
  }
  if (map.containsKey('drop_interval_sec') && map['drop_interval_sec'] is! num) {
    return false;
  }
  if (map.containsKey('fall_speed') && map['fall_speed'] is! num) {
    return false;
  }
  if (map.containsKey('image_scale') && map['image_scale'] is! num) {
    return false;
  }
  if (map.containsKey('scale_jitter') && map['scale_jitter'] is! num) {
    return false;
  }
  return true;
}
