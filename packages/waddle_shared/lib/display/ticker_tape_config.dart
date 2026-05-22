import 'dart:convert';

/// Built-in ticker time format presets (see [formatTickerTimePreset] in display).
const List<String> kTickerTimeFormatPresets = [
  '24h_hms',
  '24h_hm',
  '12h_hms_ampm',
  '12h_hm_ampm',
  '12h_hm_tt',
];

const String kDefaultTickerTimeFormatPreset = '24h_hms';

/// Resolved time ticker tape settings from `config_json`.
class TickerTapeTimeConfig {
  const TickerTapeTimeConfig({
    required this.timeFormatPreset,
    this.timeZone,
    this.labelPrefix,
  });

  final String timeFormatPreset;
  final String? timeZone;
  final String? labelPrefix;
}

/// Resolved weather ticker tape settings from `config_json`.
class TickerTapeWeatherConfig {
  const TickerTapeWeatherConfig({
    this.locationId,
    this.temperatureUnit,
  });

  final String? locationId;
  /// When set, overrides display KV `display.weather.temperature_unit`.
  final String? temperatureUnit;
}

/// Resolved news ticker tape settings from `config_json`.
class TickerTapeNewsConfig {
  const TickerTapeNewsConfig({
    this.categoryId,
    this.prefixFeedName,
  });

  final String? categoryId;
  /// When null, curation falls back to curator KV `curator.ticker.newsPrefixCategory`.
  final bool? prefixFeedName;
}

Map<String, Object?> parseTickerTapeConfigJsonMap(String rawConfigJson) {
  final t = rawConfigJson.trim();
  if (t.isEmpty || t == '{}') {
    return <String, Object?>{};
  }
  try {
    final decoded = jsonDecode(t);
    if (decoded is! Map) {
      return <String, Object?>{};
    }
    return decoded.map((k, Object? v) => MapEntry(k.toString(), v));
  } on Object {
    return <String, Object?>{};
  }
}

String _normalizeTickerTimeFormatPreset(Object? raw) {
  final s = raw == null ? '' : '$raw'.trim();
  if (kTickerTimeFormatPresets.contains(s)) {
    return s;
  }
  return kDefaultTickerTimeFormatPreset;
}

String? _optionalTrimmedString(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final t = raw.trim();
  return t.isEmpty ? null : t;
}

TickerTapeTimeConfig parseTickerTapeTimeConfig(String rawConfigJson) {
  final m = parseTickerTapeConfigJsonMap(rawConfigJson);
  return TickerTapeTimeConfig(
    timeFormatPreset: _normalizeTickerTimeFormatPreset(m['timeFormatPreset']),
    timeZone: _optionalTrimmedString(m['timeZone']),
    labelPrefix: _optionalTrimmedString(m['labelPrefix']),
  );
}

TickerTapeWeatherConfig parseTickerTapeWeatherConfig(String rawConfigJson) {
  final m = parseTickerTapeConfigJsonMap(rawConfigJson);
  final unitRaw = m['temperatureUnit'];
  String? unit;
  if (unitRaw != null) {
    final u = '$unitRaw'.trim().toLowerCase();
    if (u == 'f' || u == 'c') {
      unit = u;
    }
  }
  return TickerTapeWeatherConfig(
    locationId: _optionalTrimmedString(m['locationId']),
    temperatureUnit: unit,
  );
}

TickerTapeNewsConfig parseTickerTapeNewsConfig(String rawConfigJson) {
  final m = parseTickerTapeConfigJsonMap(rawConfigJson);
  bool? prefixFeedName;
  final prefixRaw = m['prefixFeedName'];
  if (prefixRaw is bool) {
    prefixFeedName = prefixRaw;
  } else if (prefixRaw != null) {
    final s = '$prefixRaw'.trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') {
      prefixFeedName = true;
    } else if (s == 'false' || s == '0' || s == 'no') {
      prefixFeedName = false;
    }
  }
  return TickerTapeNewsConfig(
    categoryId: _optionalTrimmedString(m['categoryId']),
    prefixFeedName: prefixFeedName,
  );
}

/// When empty or absent, returns null (meaning all enabled symbols).
List<String>? parseTickerTapeStockSymbolIds(String rawConfigJson) {
  final m = parseTickerTapeConfigJsonMap(rawConfigJson);
  final raw = m['symbolIds'];
  if (raw == null) {
    return null;
  }
  if (raw is! List) {
    return null;
  }
  final out = <String>[];
  for (final item in raw) {
    if (item is! String) {
      continue;
    }
    final id = item.trim();
    if (id.isNotEmpty) {
      out.add(id);
    }
  }
  if (out.isEmpty) {
    return null;
  }
  return out;
}

String? parseTickerTapeCategoryId(String rawConfigJson) {
  return _optionalTrimmedString(
    parseTickerTapeConfigJsonMap(rawConfigJson)['categoryId'],
  );
}

/// OpenWeather-style icon suffix from blob key `weather/icons/10d`.
String? weatherIconCodeFromBlobKey(String? blobKey) {
  if (blobKey == null || blobKey.trim().isEmpty) {
    return null;
  }
  final parts = blobKey.split('/');
  if (parts.isEmpty) {
    return null;
  }
  final last = parts.last.trim();
  if (last.length < 3) {
    return null;
  }
  return last;
}
