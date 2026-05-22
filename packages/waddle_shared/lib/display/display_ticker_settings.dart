/// Display-level ticker marquee tuning from [config_key_values].
library;

const String kDisplayTickerProgramDurationSecondsKvKey =
    'display.ticker.program_duration_seconds';
const String kDisplayTickerPixelsPerSecondKvKey =
    'display.ticker.pixels_per_second';
const String kDisplayTickerItemSeparatorKvKey =
    'display.ticker.item_separator';
const String kDisplayTickerProgramSeparatorKvKey =
    'display.ticker.program_separator';

const int kDisplayTickerProgramDurationSecondsDefault = 300;
const int kDisplayTickerPixelsPerSecondDefault = 80;

const int kDisplayTickerProgramDurationSecondsMin = 30;
const int kDisplayTickerProgramDurationSecondsMax = 1800;

const int kDisplayTickerPixelsPerSecondMin = 20;
const int kDisplayTickerPixelsPerSecondMax = 140;

/// Middle dot between ticker lines within one program.
const String kDisplayTickerSeparatorDot = 'dot';

/// Diamond icon between ticker programs in auto-scroll history.
const String kDisplayTickerSeparatorDiamond = 'diamond';

const String kDefaultDisplayTickerItemSeparator = kDisplayTickerSeparatorDot;
const String kDefaultDisplayTickerProgramSeparator =
    kDisplayTickerSeparatorDiamond;

/// Normalizes [raw] to [kDisplayTickerSeparatorDot] or [kDisplayTickerSeparatorDiamond].
String normalizeDisplayTickerSeparator(
  Object? raw, {
  required String defaultValue,
}) {
  final s = raw == null ? '' : '$raw'.trim().toLowerCase();
  if (s == kDisplayTickerSeparatorDiamond) {
    return kDisplayTickerSeparatorDiamond;
  }
  if (s == kDisplayTickerSeparatorDot) {
    return kDisplayTickerSeparatorDot;
  }
  return defaultValue;
}

/// Effective ticker program duration (RSS scroll budget) and marquee speed.
class DisplayTickerSettings {
  const DisplayTickerSettings({
    required this.programDurationSeconds,
    required this.pixelsPerSecond,
    required this.itemSeparator,
    required this.programSeparator,
  });

  final int programDurationSeconds;
  final int pixelsPerSecond;
  final String itemSeparator;
  final String programSeparator;

  static const defaults = DisplayTickerSettings(
    programDurationSeconds: kDisplayTickerProgramDurationSecondsDefault,
    pixelsPerSecond: kDisplayTickerPixelsPerSecondDefault,
    itemSeparator: kDefaultDisplayTickerItemSeparator,
    programSeparator: kDefaultDisplayTickerProgramSeparator,
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
    itemSeparator: normalizeDisplayTickerSeparator(
      kv[kDisplayTickerItemSeparatorKvKey],
      defaultValue: kDefaultDisplayTickerItemSeparator,
    ),
    programSeparator: normalizeDisplayTickerSeparator(
      kv[kDisplayTickerProgramSeparatorKvKey],
      defaultValue: kDefaultDisplayTickerProgramSeparator,
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
    itemSeparator: global.itemSeparator,
    programSeparator: global.programSeparator,
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
