import 'dart:convert';

/// Blob keys for overlay uploads must use this prefix.
const String kOverlayBlobKeyPrefix = 'overlay/';

/// Minimum seconds between falling-image spawns.
const int kFallingImagesDropIntervalSecMin = 15;

/// Maximum seconds between falling-image spawns.
const int kFallingImagesDropIntervalSecMax = 180;

/// Minimum vertical speed (screen-heights per second; lower = slower).
const double kFallingImagesFallSpeedMin = 0.05;

/// Maximum vertical speed (screen-heights per second).
const double kFallingImagesFallSpeedMax = 1.0;

final RegExp overlayBlobKeyPattern = RegExp(r'^overlay/[a-z0-9][a-z0-9_/.-]*$');

bool isValidOverlayBlobKey(String key) => overlayBlobKeyPattern.hasMatch(key.trim());

/// Resolved `config_json` for `falling_images` overlays (no Flutter types).
class FallingImagesScheduleSettings {
  const FallingImagesScheduleSettings({
    required this.imageBlobKeys,
    required this.dropIntervalSec,
    required this.fallSpeed,
  });

  static const FallingImagesScheduleSettings defaults =
      FallingImagesScheduleSettings(
        imageBlobKeys: <String>[],
        dropIntervalSec: 45,
        fallSpeed: 0.12,
      );

  final List<String> imageBlobKeys;

  /// Average seconds between occasional image drops.
  final int dropIntervalSec;

  /// Vertical speed as screen-heights per second (lower = slower fall).
  final double fallSpeed;

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
      fallSpeed = rawSpeed.toDouble().clamp(
        kFallingImagesFallSpeedMin,
        kFallingImagesFallSpeedMax,
      );
    }

    return FallingImagesScheduleSettings(
      imageBlobKeys: keys,
      dropIntervalSec: dropIntervalSec,
      fallSpeed: fallSpeed,
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
    out['fall_speed'] = (map['fall_speed'] as num).toDouble().clamp(
      kFallingImagesFallSpeedMin,
      kFallingImagesFallSpeedMax,
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
  return true;
}
