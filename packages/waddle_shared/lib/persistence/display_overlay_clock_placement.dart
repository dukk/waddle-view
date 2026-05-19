import 'display_overlay_static_image_settings.dart';

/// Default scale for clock overlays (fraction of viewport shortest side).
const double kClockOverlayScaleDefault = 0.2;

/// Keys stripped from overlay `config_json` when building slide widget config.
const Set<String> kClockOverlayPlacementKeys = {
  'x',
  'y',
  'scale',
  'opacity',
};

/// Viewport placement for digital/analog clock overlays.
class ClockOverlayPlacement {
  const ClockOverlayPlacement({
    required this.x,
    required this.y,
    required this.scale,
    required this.opacity,
  });

  static const ClockOverlayPlacement defaults = ClockOverlayPlacement(
    x: kStaticImageOverlayPositionDefault,
    y: kStaticImageOverlayPositionDefault,
    scale: kClockOverlayScaleDefault,
    opacity: 1.0,
  );

  final double x;
  final double y;
  final double scale;
  final double opacity;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'scale': scale,
        if (opacity < 1.0) 'opacity': opacity,
      };

  static ClockOverlayPlacement parseMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    return ClockOverlayPlacement(
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
    return kClockOverlayScaleDefault;
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

/// Clock-only subset of overlay config (excludes placement keys).
Map<String, dynamic> clockConfigFromOverlayMap(Map<String, dynamic> raw) {
  return Map<String, dynamic>.from(raw)
    ..removeWhere((key, _) => kClockOverlayPlacementKeys.contains(key));
}

bool _placementMapValid(Map<String, dynamic> map) {
  for (final key in kClockOverlayPlacementKeys) {
    if (map.containsKey(key) && map[key] is! num) {
      return false;
    }
  }
  return true;
}

bool validateClockOverlayPlacementMap(Map<String, dynamic> map) =>
    _placementMapValid(map);
