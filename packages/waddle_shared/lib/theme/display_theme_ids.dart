import 'display_theme_kv.dart';

/// Stable theme ids persisted under [kDisplayThemeIdKvKey].
const String kDisplayThemeNavyCoral = 'navy_coral';
const String kDisplayThemeGraphiteAmber = 'graphite_amber';

const Set<String> kRegisteredDisplayThemeIdSet = {
  kDisplayThemeNavyCoral,
  kDisplayThemeGraphiteAmber,
};

/// Normalizes a raw KV value to a known theme id (see [kRegisteredDisplayThemeIdSet]).
String normalizeDisplayThemeId(String? raw) {
  if (raw == null) {
    return kDefaultDisplayThemeId;
  }
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return kDefaultDisplayThemeId;
  }
  final id = trimmed.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  if (kRegisteredDisplayThemeIdSet.contains(id)) {
    return id;
  }
  return kDefaultDisplayThemeId;
}
