/// Display-level ticker marquee tuning from [config_key_values].
library;

const String kDisplayTickerProgramDurationSecondsKvKey =
    'display.ticker.program_duration_seconds';
const String kDisplayTickerPixelsPerSecondKvKey =
    'display.ticker.pixels_per_second';

const int kDisplayTickerProgramDurationSecondsDefault = 300;
const int kDisplayTickerPixelsPerSecondDefault = 80;

const int kDisplayTickerProgramDurationSecondsMin = 30;
const int kDisplayTickerProgramDurationSecondsMax = 1800;

const int kDisplayTickerPixelsPerSecondMin = 20;
const int kDisplayTickerPixelsPerSecondMax = 140;

/// Effective ticker program duration (RSS scroll budget) and marquee speed.
class DisplayTickerSettings {
  const DisplayTickerSettings({
    required this.programDurationSeconds,
    required this.pixelsPerSecond,
  });

  final int programDurationSeconds;
  final int pixelsPerSecond;

  static const defaults = DisplayTickerSettings(
    programDurationSeconds: kDisplayTickerProgramDurationSecondsDefault,
    pixelsPerSecond: kDisplayTickerPixelsPerSecondDefault,
  );
}

int normalizeDisplayTickerProgramDurationSeconds(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return kDisplayTickerProgramDurationSecondsDefault;
  }
  final parsed = int.tryParse(raw.trim());
  if (parsed == null) {
    return kDisplayTickerProgramDurationSecondsDefault;
  }
  return parsed.clamp(
    kDisplayTickerProgramDurationSecondsMin,
    kDisplayTickerProgramDurationSecondsMax,
  );
}

int normalizeDisplayTickerPixelsPerSecond(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return kDisplayTickerPixelsPerSecondDefault;
  }
  final parsed = int.tryParse(raw.trim());
  if (parsed == null) {
    return kDisplayTickerPixelsPerSecondDefault;
  }
  return parsed.clamp(
    kDisplayTickerPixelsPerSecondMin,
    kDisplayTickerPixelsPerSecondMax,
  );
}

DisplayTickerSettings parseDisplayTickerSettingsFromKv(Map<String, String> kv) {
  return DisplayTickerSettings(
    programDurationSeconds: normalizeDisplayTickerProgramDurationSeconds(
      kv[kDisplayTickerProgramDurationSecondsKvKey],
    ),
    pixelsPerSecond: normalizeDisplayTickerPixelsPerSecond(
      kv[kDisplayTickerPixelsPerSecondKvKey],
    ),
  );
}

/// Merge display defaults with optional per-curator overrides (null = display default).
DisplayTickerSettings mergeDisplayTickerSettings(
  DisplayTickerSettings global, {
  int? programDurationSecondsOverride,
  int? pixelsPerSecondOverride,
}) {
  return DisplayTickerSettings(
    programDurationSeconds:
        programDurationSecondsOverride ?? global.programDurationSeconds,
    pixelsPerSecond: pixelsPerSecondOverride ?? global.pixelsPerSecond,
  );
}

int? normalizeTickerProgramDurationSecondsOverride(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  final parsed = int.tryParse(raw.trim());
  if (parsed == null) {
    return null;
  }
  return parsed.clamp(
    kDisplayTickerProgramDurationSecondsMin,
    kDisplayTickerProgramDurationSecondsMax,
  );
}

int? normalizeTickerPixelsPerSecondOverride(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  final parsed = int.tryParse(raw.trim());
  if (parsed == null) {
    return null;
  }
  return parsed.clamp(
    kDisplayTickerPixelsPerSecondMin,
    kDisplayTickerPixelsPerSecondMax,
  );
}
