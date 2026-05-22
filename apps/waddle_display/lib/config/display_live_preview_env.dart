import 'package:waddle_shared/config/display_live_preview.dart';

import 'display_env.dart';

/// Applies [WADDLE_DISPLAY_LIVE_PREVIEW_*] env vars as defaults when KV is unset.
void applyDisplayLivePreviewEnvDefaults(Map<String, String> env) {
  final enabledRaw = (env[kDisplayLivePreviewEnabledEnv] ?? '').trim();
  if (enabledRaw.isNotEmpty) {
    DisplayLivePreviewEnvDefaults.enabled =
        parseDisplayLivePreviewEnabled(enabledRaw);
  }
  final fpsRaw = (env[kDisplayLivePreviewFpsEnv] ?? '').trim();
  if (fpsRaw.isNotEmpty) {
    DisplayLivePreviewEnvDefaults.fps = normalizeDisplayLivePreviewFps(fpsRaw);
  }
  final widthRaw = (env[kDisplayLivePreviewWidthEnv] ?? '').trim();
  if (widthRaw.isNotEmpty) {
    DisplayLivePreviewEnvDefaults.width =
        normalizeDisplayLivePreviewWidth(widthRaw);
  }
  final qualityRaw = (env[kDisplayLivePreviewQualityEnv] ?? '').trim();
  if (qualityRaw.isNotEmpty) {
    DisplayLivePreviewEnvDefaults.quality =
        normalizeDisplayLivePreviewQuality(qualityRaw);
  }
}
