/// Data collection engine idle and low-power display tuning ([config_key_values] + env).
library;

const String kDisplayCollectIdleSecondsKvKey = 'display.collect.idle_seconds';
const String kDisplayLowPowerEnabledKvKey = 'display.low_power.enabled';

/// Env fallback when KV is unset (see [DisplayCollectEnvDefaults]).
const String kDisplayCollectIdleSecondsEnv =
    'WADDLE_DISPLAY_COLLECT_IDLE_SECONDS';
const String kDisplayLowPowerEnv = 'WADDLE_DISPLAY_LOW_POWER';

const int kDefaultDisplayCollectIdleSeconds = 30;
const int kDisplayCollectIdleSecondsMin = 15;
const int kDisplayCollectIdleSecondsMax = 600;

/// When low power is on, idle is at least this many seconds (even if KV is lower).
const int kDisplayLowPowerMinCollectIdleSeconds = 60;

/// When low power is on, ticker speed is capped at this pixels/sec (if higher configured).
const int kDisplayLowPowerMaxTickerPixelsPerSecond = 40;

/// Optional env fallbacks when KV is unset (wired from waddle_display startup).
abstract final class DisplayCollectEnvDefaults {
  const DisplayCollectEnvDefaults._();

  static int? collectIdleSeconds;
  static bool? lowPowerEnabled;
}

int normalizeDisplayCollectIdleSeconds(Object? raw) {
  if (raw is int) {
    return raw.clamp(
      kDisplayCollectIdleSecondsMin,
      kDisplayCollectIdleSecondsMax,
    );
  }
  final parsed = int.tryParse('${raw ?? ''}'.trim());
  if (parsed == null) {
    return kDefaultDisplayCollectIdleSeconds;
  }
  return parsed.clamp(
    kDisplayCollectIdleSecondsMin,
    kDisplayCollectIdleSecondsMax,
  );
}

bool parseDisplayLowPowerEnabled(Object? raw) {
  if (raw == null) {
    return false;
  }
  if (raw is bool) {
    return raw;
  }
  final s = '$raw'.trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes' || s == 'on';
}

/// Effective engine idle between full provider rounds (release/profile).
int resolveDisplayCollectIdleSeconds(
  Map<String, String> kv, {
  bool debugMode = false,
}) {
  if (debugMode) {
    return 5;
  }
  final fromKv = kv[kDisplayCollectIdleSecondsKvKey];
  final base = fromKv != null && fromKv.trim().isNotEmpty
      ? normalizeDisplayCollectIdleSeconds(fromKv)
      : (DisplayCollectEnvDefaults.collectIdleSeconds != null
            ? normalizeDisplayCollectIdleSeconds(
                DisplayCollectEnvDefaults.collectIdleSeconds,
              )
            : kDefaultDisplayCollectIdleSeconds);
  if (parseDisplayLowPowerEnabled(kv[kDisplayLowPowerEnabledKvKey]) ||
      (DisplayCollectEnvDefaults.lowPowerEnabled ?? false)) {
    return base < kDisplayLowPowerMinCollectIdleSeconds
        ? kDisplayLowPowerMinCollectIdleSeconds
        : base;
  }
  return base;
}

/// Applies low-power ticker cap on top of parsed [DisplayTickerSettings] pixels.
int effectiveDisplayTickerPixelsPerSecond({
  required int configuredPixelsPerSecond,
  required Map<String, String> kv,
}) {
  final lowPower =
      parseDisplayLowPowerEnabled(kv[kDisplayLowPowerEnabledKvKey]) ||
      (DisplayCollectEnvDefaults.lowPowerEnabled ?? false);
  if (!lowPower) {
    return configuredPixelsPerSecond;
  }
  return configuredPixelsPerSecond > kDisplayLowPowerMaxTickerPixelsPerSecond
      ? kDisplayLowPowerMaxTickerPixelsPerSecond
      : configuredPixelsPerSecond;
}

void applyDisplayCollectEnvDefaults(Map<String, String> env) {
  final idleRaw = (env[kDisplayCollectIdleSecondsEnv] ?? '').trim();
  if (idleRaw.isNotEmpty) {
    DisplayCollectEnvDefaults.collectIdleSeconds =
        normalizeDisplayCollectIdleSeconds(idleRaw);
  }
  final lowRaw = (env[kDisplayLowPowerEnv] ?? '').trim();
  if (lowRaw.isNotEmpty) {
    DisplayCollectEnvDefaults.lowPowerEnabled = parseDisplayLowPowerEnabled(
      lowRaw,
    );
  }
}
