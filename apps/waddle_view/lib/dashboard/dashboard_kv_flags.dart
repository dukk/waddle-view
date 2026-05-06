/// Parses dashboard KV string values commonly used as on/off toggles.
bool isTruthyDashboardKvFlag(String? raw, {required bool defaultValue}) {
  if (raw == null) {
    return defaultValue;
  }
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) {
    return defaultValue;
  }
  if (normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes' ||
      normalized == 'on') {
    return true;
  }
  if (normalized == '0' ||
      normalized == 'false' ||
      normalized == 'no' ||
      normalized == 'off') {
    return false;
  }
  return defaultValue;
}
