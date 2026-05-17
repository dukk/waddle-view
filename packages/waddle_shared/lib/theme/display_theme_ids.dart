import 'display_theme_kv.dart';

/// Stable theme ids persisted under [kDisplayThemeIdKvKey].
const String kDisplayThemeNavyCoral = 'navy_coral';
const String kDisplayThemeGraphiteAmber = 'graphite_amber';

/// Coolors trending palettes (https://coolors.co/palettes/trending).
const String kDisplayThemeTealGoldSunset = 'teal_gold_sunset';
const String kDisplayThemeOceanDepth = 'ocean_depth';
const String kDisplayThemeForestCream = 'forest_cream';
const String kDisplayThemeHeritageCoast = 'heritage_coast';
const String kDisplayThemePlumEmber = 'plum_ember';
const String kDisplayThemeSlateCrimson = 'slate_crimson';
const String kDisplayThemeWineEmber = 'wine_ember';
const String kDisplayThemeDopaminePop = 'dopamine_pop';
const String kDisplayThemeSageWellness = 'sage_wellness';
const String kDisplayThemeWarmMinimal = 'warm_minimal';

const Set<String> kRegisteredDisplayThemeIdSet = {
  kDisplayThemeNavyCoral,
  kDisplayThemeGraphiteAmber,
  kDisplayThemeTealGoldSunset,
  kDisplayThemeOceanDepth,
  kDisplayThemeForestCream,
  kDisplayThemeHeritageCoast,
  kDisplayThemePlumEmber,
  kDisplayThemeSlateCrimson,
  kDisplayThemeWineEmber,
  kDisplayThemeDopaminePop,
  kDisplayThemeSageWellness,
  kDisplayThemeWarmMinimal,
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
