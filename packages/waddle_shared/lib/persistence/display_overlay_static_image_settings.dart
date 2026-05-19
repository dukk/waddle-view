import 'dart:convert';

import 'display_overlay_falling_images_settings.dart';

/// Minimum [StaticImageOverlaySettings.scale] (fraction of viewport shortest side).
const double kStaticImageOverlayScaleMin = kFallingImagesImageScaleMin;

/// Maximum [StaticImageOverlaySettings.scale].
const double kStaticImageOverlayScaleMax = kFallingImagesImageScaleMax;

/// Default scale when unset or invalid.
const double kStaticImageOverlayScaleDefault = 0.12;

/// Default top-left anchor when unset.
const double kStaticImageOverlayPositionDefault = 0.05;

/// Stable overlay id created when migrating legacy `display.image_overlay` KV.
const String kMigratedDisplayImageOverlayId = 'migrated_display_image_overlay';

/// Legacy KV key removed in schema 31.
const String kLegacyDisplayImageOverlayKvKey = 'display.image_overlay';

/// Resolved static image overlay settings from overlay `config_json`.
class StaticImageOverlaySettings {
  const StaticImageOverlaySettings({
    required this.imageBlobKey,
    required this.x,
    required this.y,
    required this.scale,
    required this.opacity,
  });

  static const StaticImageOverlaySettings defaults = StaticImageOverlaySettings(
    imageBlobKey: '',
    x: kStaticImageOverlayPositionDefault,
    y: kStaticImageOverlayPositionDefault,
    scale: kStaticImageOverlayScaleDefault,
    opacity: 1.0,
  );

  final String imageBlobKey;
  final double x;
  final double y;
  final double scale;
  final double opacity;

  bool get isRenderable =>
      imageBlobKey.isNotEmpty && isValidOverlayBlobKey(imageBlobKey);

  Map<String, dynamic> toJson() => {
        if (imageBlobKey.isNotEmpty) 'image_blob_key': imageBlobKey,
        'x': x,
        'y': y,
        'scale': scale,
        if (opacity < 1.0) 'opacity': opacity,
      };

  static StaticImageOverlaySettings parse(String configJson) {
    if (configJson.trim().isEmpty) {
      return defaults;
    }
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is Map<String, dynamic>) {
        return parseMap(decoded);
      }
      if (decoded is Map) {
        return parseMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      /* fall through */
    }
    return defaults;
  }

  static StaticImageOverlaySettings parseMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    final blobRaw = raw['image_blob_key'];
    final blobKey = blobRaw is String ? blobRaw.trim() : '';
    final imageBlobKey =
        blobKey.isNotEmpty && isValidOverlayBlobKey(blobKey) ? blobKey : '';

    return StaticImageOverlaySettings(
      imageBlobKey: imageBlobKey,
      x: _clamp01(raw['x'], kStaticImageOverlayPositionDefault),
      y: _clamp01(raw['y'], kStaticImageOverlayPositionDefault),
      scale: _clampScale(raw['scale']),
      opacity: _clampOpacity(raw['opacity']),
    );
  }
}

double _clamp01(Object? raw, double fallback) {
  final v = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (v == null || !v.isFinite) {
    return fallback;
  }
  return v.clamp(0.0, 1.0);
}

double _clampScale(Object? raw) {
  final v = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (v == null || !v.isFinite) {
    return kStaticImageOverlayScaleDefault;
  }
  return v.clamp(kStaticImageOverlayScaleMin, kStaticImageOverlayScaleMax);
}

double _clampOpacity(Object? raw) {
  if (raw == null) {
    return 1.0;
  }
  final v = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (v == null || !v.isFinite) {
    return 1.0;
  }
  return v.clamp(0.0, 1.0);
}

/// Returns `null` when [raw] is not a JSON object or violates static-image rules.
String? normalizeStaticImageSettingsJsonString(String raw) {
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
  map.remove('enabled');
  if (!_staticImageSettingsMapValid(map)) {
    return null;
  }
  final settings = StaticImageOverlaySettings.parseMap(map);
  return jsonEncode(settings.toJson());
}

bool _staticImageSettingsMapValid(Map<String, dynamic> map) {
  if (map.containsKey('image_blob_key') &&
      (map['image_blob_key'] is! String ||
          (map['image_blob_key'] as String).trim().isNotEmpty &&
              !isValidOverlayBlobKey((map['image_blob_key'] as String).trim()))) {
    return false;
  }
  if (map.containsKey('x') && map['x'] is! num) {
    return false;
  }
  if (map.containsKey('y') && map['y'] is! num) {
    return false;
  }
  if (map.containsKey('scale') && map['scale'] is! num) {
    return false;
  }
  if (map.containsKey('opacity') && map['opacity'] is! num) {
    return false;
  }
  return true;
}

/// Parses legacy KV JSON (`enabled` + layout fields) for schema 31 migration.
StaticImageOverlaySettings? parseLegacyDisplayImageOverlayKv(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is! Map) {
      return null;
    }
    final map = decoded.cast<String, dynamic>();
    if (map['enabled'] != true) {
      return null;
    }
    final settings = StaticImageOverlaySettings.parseMap(map);
    return settings.isRenderable ? settings : null;
  } on Object {
    return null;
  }
}
