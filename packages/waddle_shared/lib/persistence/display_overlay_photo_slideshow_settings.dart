import 'dart:convert';

import 'display_overlay_static_image_settings.dart';

/// Minimum [PhotoSlideshowOverlaySettings.intervalSec].
const int kPhotoSlideshowIntervalSecMin = 5;

/// Maximum [PhotoSlideshowOverlaySettings.intervalSec].
const int kPhotoSlideshowIntervalSecMax = 3600;

/// Default cycle interval when unset or invalid.
const int kPhotoSlideshowIntervalSecDefault = 60;

/// Aspect filter: no restriction.
const String kPhotoSlideshowAspectAny = 'any';

/// Aspect filter: width notably greater than height.
const String kPhotoSlideshowAspectLandscape = 'landscape';

/// Aspect filter: height notably greater than width.
const String kPhotoSlideshowAspectPortrait = 'portrait';

/// Aspect filter: near-square (ratio ~1).
const String kPhotoSlideshowAspectSquare = 'square';

/// Aspect filter: ~16:9.
const String kPhotoSlideshowAspectWidescreen = 'widescreen';

/// Aspect filter: ~4:3.
const String kPhotoSlideshowAspectStandard43 = 'standard_4_3';

/// Allowed [PhotoSlideshowOverlaySettings.aspectRatio] values.
const List<String> kPhotoSlideshowAspectRatioValues = [
  kPhotoSlideshowAspectAny,
  kPhotoSlideshowAspectLandscape,
  kPhotoSlideshowAspectPortrait,
  kPhotoSlideshowAspectSquare,
  kPhotoSlideshowAspectWidescreen,
  kPhotoSlideshowAspectStandard43,
];

/// Resolved photo slideshow overlay settings from overlay `config_json`.
class PhotoSlideshowOverlaySettings {
  const PhotoSlideshowOverlaySettings({
    required this.x,
    required this.y,
    required this.scale,
    required this.opacity,
    required this.intervalSec,
    required this.categoryIds,
    required this.aspectRatio,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
  });

  static const PhotoSlideshowOverlaySettings defaults =
      PhotoSlideshowOverlaySettings(
    x: kStaticImageOverlayPositionDefault,
    y: kStaticImageOverlayPositionDefault,
    scale: kStaticImageOverlayScaleDefault,
    opacity: 1.0,
    intervalSec: kPhotoSlideshowIntervalSecDefault,
    categoryIds: [],
    aspectRatio: kPhotoSlideshowAspectAny,
  );

  final double x;
  final double y;
  final double scale;
  final double opacity;
  final int intervalSec;
  final List<String> categoryIds;
  final String aspectRatio;
  final int? minWidth;
  final int? maxWidth;
  final int? minHeight;
  final int? maxHeight;

  bool get isRenderable => intervalSec >= kPhotoSlideshowIntervalSecMin;

  bool get hasDimensionOrAspectFilter =>
      aspectRatio != kPhotoSlideshowAspectAny ||
      minWidth != null ||
      maxWidth != null ||
      minHeight != null ||
      maxHeight != null;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'scale': scale,
        if (opacity < 1.0) 'opacity': opacity,
        'interval_sec': intervalSec,
        if (categoryIds.isNotEmpty) 'category_ids': categoryIds,
        if (aspectRatio != kPhotoSlideshowAspectAny) 'aspect_ratio': aspectRatio,
        if (minWidth != null) 'min_width': minWidth,
        if (maxWidth != null) 'max_width': maxWidth,
        if (minHeight != null) 'min_height': minHeight,
        if (maxHeight != null) 'max_height': maxHeight,
      };

  static PhotoSlideshowOverlaySettings parse(String configJson) {
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

  static PhotoSlideshowOverlaySettings parseMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    return PhotoSlideshowOverlaySettings(
      x: _clamp01(raw['x'], kStaticImageOverlayPositionDefault),
      y: _clamp01(raw['y'], kStaticImageOverlayPositionDefault),
      scale: _clampScale(raw['scale']),
      opacity: _clampOpacity(raw['opacity']),
      intervalSec: _clampIntervalSec(raw['interval_sec']),
      categoryIds: _parseCategoryIds(raw['category_ids']),
      aspectRatio: _parseAspectRatio(raw['aspect_ratio']),
      minWidth: _parseOptionalPositiveInt(raw['min_width']),
      maxWidth: _parseOptionalPositiveInt(raw['max_width']),
      minHeight: _parseOptionalPositiveInt(raw['min_height']),
      maxHeight: _parseOptionalPositiveInt(raw['max_height']),
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

int _clampIntervalSec(Object? raw) {
  final v = raw is num ? raw.round() : int.tryParse('$raw');
  if (v == null) {
    return kPhotoSlideshowIntervalSecDefault;
  }
  return v.clamp(kPhotoSlideshowIntervalSecMin, kPhotoSlideshowIntervalSecMax);
}

List<String> _parseCategoryIds(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final out = <String>[];
  for (final item in raw) {
    if (item is! String) {
      continue;
    }
    final id = item.trim();
    if (id.isNotEmpty && !out.contains(id)) {
      out.add(id);
    }
  }
  return out;
}

String _parseAspectRatio(Object? raw) {
  if (raw is! String) {
    return kPhotoSlideshowAspectAny;
  }
  final v = raw.trim();
  if (kPhotoSlideshowAspectRatioValues.contains(v)) {
    return v;
  }
  return kPhotoSlideshowAspectAny;
}

int? _parseOptionalPositiveInt(Object? raw) {
  if (raw == null) {
    return null;
  }
  final v = raw is num ? raw.round() : int.tryParse('$raw');
  if (v == null || v <= 0) {
    return null;
  }
  return v;
}

/// Returns `null` when [raw] is not a JSON object or violates slideshow rules.
String? normalizePhotoSlideshowSettingsJsonString(String raw) {
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
  if (!_photoSlideshowSettingsMapValid(map)) {
    return null;
  }
  final settings = PhotoSlideshowOverlaySettings.parseMap(map);
  return jsonEncode(settings.toJson());
}

bool _photoSlideshowSettingsMapValid(Map<String, dynamic> map) {
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
  if (map.containsKey('interval_sec') && map['interval_sec'] is! num) {
    return false;
  }
  if (map.containsKey('category_ids') && map['category_ids'] is! List) {
    return false;
  }
  if (map.containsKey('aspect_ratio') &&
      (map['aspect_ratio'] is! String ||
          !kPhotoSlideshowAspectRatioValues.contains(
            (map['aspect_ratio'] as String).trim(),
          ))) {
    return false;
  }
  for (final key in ['min_width', 'max_width', 'min_height', 'max_height']) {
    if (map.containsKey(key) && map[key] is! num) {
      return false;
    }
  }
  return true;
}
