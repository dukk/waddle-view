/// In-app live preview (window capture + JPEG over WebSocket) in [config_key_values].
library;

import 'package:meta/meta.dart';

const String kDisplayLivePreviewEnabledKvKey = 'display.live_preview.enabled';
const String kDisplayLivePreviewFpsKvKey = 'display.live_preview.fps';
const String kDisplayLivePreviewWidthKvKey = 'display.live_preview.width';
const String kDisplayLivePreviewQualityKvKey = 'display.live_preview.quality';

const int kDefaultDisplayLivePreviewFps = 10;
const int kDefaultDisplayLivePreviewWidth = 1280;
const int kDefaultDisplayLivePreviewQuality = 75;

/// Optional env fallbacks when KV is unset (see [DisplayLivePreviewEnvDefaults]).
abstract final class DisplayLivePreviewEnvDefaults {
  const DisplayLivePreviewEnvDefaults._();

  static bool? enabled;
  static int? fps;
  static int? width;
  static int? quality;
}

/// Parsed live-preview settings from KV plus optional env defaults.
@immutable
class DisplayLivePreviewConfig {
  const DisplayLivePreviewConfig({
    required this.enabled,
    required this.fps,
    required this.width,
    required this.quality,
  });

  final bool enabled;
  final int fps;
  final int width;
  final int quality;

  /// True when enabled and capture parameters are usable.
  bool get configured => enabled && fps > 0 && width > 0 && quality > 0;
}

bool parseDisplayLivePreviewEnabled(Object? raw) {
  if (raw == null) return false;
  if (raw is bool) return raw;
  final s = '$raw'.trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes' || s == 'on';
}

int normalizeDisplayLivePreviewFps(Object? raw) {
  if (raw is int) {
    return raw.clamp(1, 30);
  }
  final parsed = int.tryParse('${raw ?? ''}'.trim());
  if (parsed == null) {
    return kDefaultDisplayLivePreviewFps;
  }
  return parsed.clamp(1, 30);
}

int normalizeDisplayLivePreviewWidth(Object? raw) {
  if (raw is int) {
    return raw.clamp(320, 3840);
  }
  final parsed = int.tryParse('${raw ?? ''}'.trim());
  if (parsed == null) {
    return kDefaultDisplayLivePreviewWidth;
  }
  return parsed.clamp(320, 3840);
}

int normalizeDisplayLivePreviewQuality(Object? raw) {
  if (raw is int) {
    return raw.clamp(30, 95);
  }
  final parsed = int.tryParse('${raw ?? ''}'.trim());
  if (parsed == null) {
    return kDefaultDisplayLivePreviewQuality;
  }
  return parsed.clamp(30, 95);
}

DisplayLivePreviewConfig displayLivePreviewConfigFromKv(Map<String, String> kv) {
  final enabledRaw = kv[kDisplayLivePreviewEnabledKvKey] ??
      DisplayLivePreviewEnvDefaults.enabled?.toString();
  final enabled = parseDisplayLivePreviewEnabled(enabledRaw);
  final fps = normalizeDisplayLivePreviewFps(
    kv[kDisplayLivePreviewFpsKvKey] ??
        DisplayLivePreviewEnvDefaults.fps?.toString(),
  );
  final width = normalizeDisplayLivePreviewWidth(
    kv[kDisplayLivePreviewWidthKvKey] ??
        DisplayLivePreviewEnvDefaults.width?.toString(),
  );
  final quality = normalizeDisplayLivePreviewQuality(
    kv[kDisplayLivePreviewQualityKvKey] ??
        DisplayLivePreviewEnvDefaults.quality?.toString(),
  );
  return DisplayLivePreviewConfig(
    enabled: enabled,
    fps: fps,
    width: width,
    quality: quality,
  );
}

Map<String, dynamic> displayLivePreviewSettingsJson(DisplayLivePreviewConfig config) {
  return {
    'display_live_preview_enabled': config.enabled,
    'display_live_preview_fps': config.fps,
    'display_live_preview_width': config.width,
    'display_live_preview_quality': config.quality,
  };
}
