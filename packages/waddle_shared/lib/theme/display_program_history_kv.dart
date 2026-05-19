/// [AppDatabase.configKeyValues] key: max screen programs kept for back-nav and
/// recent-placement weighting (shared across all curator configurations).
const String kDisplayProgramHistoryDepthKvKey = 'display.program.history_depth';

/// Default when the key is missing or the value is invalid.
const int kDefaultDisplayProgramHistoryDepth = 5;

const int kDisplayProgramHistoryDepthMin = 1;
const int kDisplayProgramHistoryDepthMax = 10;

/// Clamps [raw] to [kDisplayProgramHistoryDepthMin]–[kDisplayProgramHistoryDepthMax].
int normalizeDisplayProgramHistoryDepth(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return kDefaultDisplayProgramHistoryDepth;
  }
  final parsed = int.tryParse(raw.trim());
  if (parsed == null) {
    return kDefaultDisplayProgramHistoryDepth;
  }
  return parsed.clamp(
    kDisplayProgramHistoryDepthMin,
    kDisplayProgramHistoryDepthMax,
  );
}
