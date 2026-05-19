import 'dart:convert';

import 'package:waddle_shared/persistence/display_overlay_falling_images_settings.dart';

/// KV key for the always-on display image overlay (JSON object).
const String kDisplayImageOverlayKvKey = 'display.image_overlay';

/// Minimum [DisplayImageOverlaySettings.scale] (fraction of viewport shortest side).
const double kDisplayImageOverlayScaleMin = kFallingImagesImageScaleMin;

/// Maximum [DisplayImageOverlaySettings.scale].
const double kDisplayImageOverlayScaleMax = kFallingImagesImageScaleMax;

/// Default scale when unset or invalid.
const double kDisplayImageOverlayScaleDefault = 0.12;

/// Default top-left anchor when unset.
const double kDisplayImageOverlayPositionDefault = 0.05;

/// Resolved always-on image overlay settings from [kDisplayImageOverlayKvKey].
class DisplayImageOverlaySettings {
  const DisplayImageOverlaySettings({
    required this.enabled,
    required this.imageBlobKey,
    required this.x,
    required this.y,
    required this.scale,
    required this.opacity,
  });

  static const DisplayImageOverlaySettings defaults = DisplayImageOverlaySettings(
    enabled: false,
    imageBlobKey: '',
    x: kDisplayImageOverlayPositionDefault,
    y: kDisplayImageOverlayPositionDefault,
    scale: kDisplayImageOverlayScaleDefault,
    opacity: 1.0,
  );

  final bool enabled;
  final String imageBlobKey;
  final double x;
  final double y;
  final double scale;
  final double opacity;

  bool get isRenderable =>
      enabled && imageBlobKey.isNotEmpty && isValidOverlayBlobKey(imageBlobKey);

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (imageBlobKey.isNotEmpty) 'image_blob_key': imageBlobKey,
        'x': x,
        'y': y,
        'scale': scale,
        if (opacity < 1.0) 'opacity': opacity,
      };

  static DisplayImageOverlaySettings parse(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    final enabled = raw['enabled'] == true;
    final blobRaw = raw['image_blob_key'];
    final blobKey = blobRaw is String ? blobRaw.trim() : '';
    final imageBlobKey =
        blobKey.isNotEmpty && isValidOverlayBlobKey(blobKey) ? blobKey : '';

    return DisplayImageOverlaySettings(
      enabled: enabled,
      imageBlobKey: imageBlobKey,
      x: _clamp01(raw['x'], kDisplayImageOverlayPositionDefault),
      y: _clamp01(raw['y'], kDisplayImageOverlayPositionDefault),
      scale: _clampScale(raw['scale']),
      opacity: _clampOpacity(raw['opacity']),
    );
  }

  static DisplayImageOverlaySettings decodeKvValue(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return defaults;
    }
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is Map<String, dynamic>) {
        return parse(decoded);
      }
      if (decoded is Map) {
        return parse(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      /* fall through */
    }
    return defaults;
  }

  static String encodeKvValue(DisplayImageOverlaySettings settings) =>
      jsonEncode(settings.toJson());

  DisplayImageOverlaySettings mergePartial(Map<String, dynamic> patch) {
    final merged = <String, dynamic>{
      ...toJson(),
      ...patch,
    };
    return parse(merged);
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
    return kDisplayImageOverlayScaleDefault;
  }
  return v.clamp(kDisplayImageOverlayScaleMin, kDisplayImageOverlayScaleMax);
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
