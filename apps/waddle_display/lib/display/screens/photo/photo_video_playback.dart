// Layout and retry helpers for VideoSlideWidget media_kit playback.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:waddle_display/config/display_env.dart';

/// Minimum layout extent before attaching a media_kit [Video] texture surface.
const double kPexelsVideoMinLayoutExtent = 32;

/// Maximum automatic playback restarts after a [Player.stream.error] event.
const int kPexelsVideoMaxPlaybackRetries = 3;

/// Default GPU texture budget on embedded Linux signage (720p).
const int kPexelsVideoDefaultEmbeddedMaxTexturePixels = 1280 * 720;

/// Default mpv hardware decoder on embedded Linux (`drm` via Mesa/V3D).
const String kPexelsVideoDefaultEmbeddedHwdec = 'drm';

/// Whether [width] and [height] from a [LayoutBuilder] are safe for video output.
bool pexelsVideoLayoutSizeReady(double width, double height) {
  if (!width.isFinite || !height.isFinite) {
    return false;
  }
  return width >= kPexelsVideoMinLayoutExtent &&
      height >= kPexelsVideoMinLayoutExtent;
}

/// Backoff before retry attempt [attempt] (1-based).
Duration pexelsVideoRetryDelay(int attempt) {
  final clamped = attempt.clamp(1, kPexelsVideoMaxPlaybackRetries);
  return Duration(milliseconds: 400 * clamped);
}

@visibleForTesting
bool? embeddedSignageLinuxHostOverride;

/// True on Linux ARM / Raspberry Pi class devices where GPU memory is tight.
bool isEmbeddedSignageLinuxHost() {
  final override = embeddedSignageLinuxHostOverride;
  if (override != null) {
    return override;
  }
  if (kIsWeb) {
    return false;
  }
  try {
    if (!Platform.isLinux) {
      return false;
    }
  } on Object {
    return false;
  }
  final version = Platform.version.toLowerCase();
  if (version.contains('arm') ||
      version.contains('aarch64') ||
      version.contains('riscv')) {
    return true;
  }
  try {
    final model = File('/proc/device-tree/model');
    if (model.existsSync()) {
      final text = model.readAsStringSync().toLowerCase();
      if (text.contains('raspberry')) {
        return true;
      }
    }
  } on Object {
    // Optional on non-Pi Linux boards.
  }
  return false;
}

@visibleForTesting
int? maxTexturePixelCountOverride;

@visibleForTesting
String? pexelsVideoHwdecOverride;

/// Max width×height for a media_kit output texture; `null` means layout size only.
int? pexelsVideoMaxTexturePixelCount() {
  final override = maxTexturePixelCountOverride;
  if (override != null) {
    return override > 0 ? override : null;
  }
  final fromEnv = Platform.environment[kDisplayPexelsVideoMaxTexturePixelsEnv]
      ?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) {
    final parsed = int.tryParse(fromEnv);
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }
  if (isEmbeddedSignageLinuxHost()) {
    return kPexelsVideoDefaultEmbeddedMaxTexturePixels;
  }
  return null;
}

/// Capped integer texture dimensions for [layoutWidth]×[layoutHeight].
({int width, int height}) pexelsVideoTextureDimensions({
  required double layoutWidth,
  required double layoutHeight,
}) {
  var w = layoutWidth.round().clamp(1, 7680);
  var h = layoutHeight.round().clamp(1, 7680);
  final maxPx = pexelsVideoMaxTexturePixelCount();
  if (maxPx == null) {
    return (width: w, height: h);
  }
  final pixels = w * h;
  if (pixels <= maxPx) {
    return (width: w, height: h);
  }
  final scale = math.sqrt(maxPx / pixels);
  final minExtent = kPexelsVideoMinLayoutExtent.round();
  w = math.max(minExtent, (w * scale).round());
  h = math.max(minExtent, (h * scale).round());
  return (width: w, height: h);
}

/// mpv `--hwdec` for Pexels playback; embedded Linux defaults to [drm].
String? pexelsVideoHwdecForPlayback() {
  final override = pexelsVideoHwdecOverride;
  if (override != null) {
    return override.isEmpty ? null : override;
  }
  final fromEnv = Platform.environment[kDisplayPexelsVideoHwdecEnv]?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv;
  }
  if (isEmbeddedSignageLinuxHost()) {
    return kPexelsVideoDefaultEmbeddedHwdec;
  }
  return null;
}

/// media_kit [VideoController] options for signage (caps GPU memory on Pi).
mkv.VideoControllerConfiguration pexelsVideoControllerConfiguration({
  required double layoutWidth,
  required double layoutHeight,
}) {
  final dims = pexelsVideoTextureDimensions(
    layoutWidth: layoutWidth,
    layoutHeight: layoutHeight,
  );
  final hwdec = pexelsVideoHwdecForPlayback();
  return mkv.VideoControllerConfiguration(
    width: dims.width,
    height: dims.height,
    hwdec: hwdec,
  );
}
