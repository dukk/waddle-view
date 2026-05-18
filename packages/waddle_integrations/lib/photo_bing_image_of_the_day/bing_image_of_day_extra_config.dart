import 'dart:convert';

/// Suffix before `.jpg` in Bing wallpaper URLs (`{base}{urlbase}_{suffix}.jpg`).
///
/// Matches [TimothyYe/bing-wallpaper](https://github.com/TimothyYe/bing-wallpaper)
/// `FullResolution` keys (subset; includes portrait for rotated displays).
const Set<String> kBingWallpaperResolutionSuffixes = {
  'UHD',
  '1920x1200',
  '1920x1080',
  '1366x768',
  '1080x1920',
  '768x1280',
};

class BingImageOfDayExtraConfig {
  const BingImageOfDayExtraConfig({
    required this.retentionDays,
    required this.market,
    required this.resolution,
    required this.category,
  });

  /// Days to keep Bing photos; `<= 0` disables age-based pruning.
  final int retentionDays;

  /// Bing `mkt` parameter (e.g. `en-US`, `en-GB`).
  final String market;

  /// Resolution token before `.jpg` (must be in [kBingWallpaperResolutionSuffixes]).
  final String resolution;

  /// [ContentCategories.id] slug for stored photos.
  final String category;

  static BingImageOfDayExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return _defaults;
    }
    try {
      final m = jsonDecode(configJson) as Map<String, dynamic>;
      return BingImageOfDayExtraConfig(
        retentionDays: _retentionDays(m['retentionDays']),
        market: _stringField(m['market'], _defaults.market),
        resolution: _resolution(m['resolution']),
        category: _stringField(m['category'], _defaults.category),
      );
    } on Object {
      return _defaults;
    }
  }

  static const _defaults = BingImageOfDayExtraConfig(
    retentionDays: 1,
    market: 'en-US',
    resolution: 'UHD',
    category: 'bing',
  );
}

int _retentionDays(Object? v) {
  if (v is int) {
    return v;
  }
  if (v is num) {
    return v.toInt();
  }
  return BingImageOfDayExtraConfig._defaults.retentionDays;
}

String _stringField(Object? v, String fallback) {
  if (v is String && v.trim().isNotEmpty) {
    return v.trim();
  }
  return fallback;
}

String _resolution(Object? v) {
  final raw = v is String ? v.trim() : '';
  if (raw.isNotEmpty && kBingWallpaperResolutionSuffixes.contains(raw)) {
    return raw;
  }
  return BingImageOfDayExtraConfig._defaults.resolution;
}
