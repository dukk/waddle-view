import 'dart:convert';

import '../weather_openweathermap/weather_provider_extra_config.dart';

class EarthImageryExtraConfig {
  const EarthImageryExtraConfig({
    required this.retentionDays,
    required this.category,
    required this.lookbackDays,
    required this.dim,
    required this.defaultLocation,
  });

  final int retentionDays;
  final String category;
  final int lookbackDays;
  final double dim;
  final WeatherLocationConfig defaultLocation;

  static const defaults = EarthImageryExtraConfig(
    retentionDays: 30,
    category: 'nasa_earth',
    lookbackDays: 16,
    dim: 0.15,
    defaultLocation: WeatherLocationConfig(
      name: kDefaultWeatherLocationName,
      latitude: kDefaultWeatherLatitude,
      longitude: kDefaultWeatherLongitude,
    ),
  );

  static EarthImageryExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return defaults;
    }
    try {
      final m = jsonDecode(configJson) as Map<String, dynamic>;
      final location =
          WeatherProviderExtraConfig.parse(configJson).defaultLocation;
      return EarthImageryExtraConfig(
        retentionDays: _intField(m['retentionDays'], defaults.retentionDays),
        category: _stringField(m['category'], defaults.category),
        lookbackDays: _clampDays(m['lookbackDays']),
        dim: _dim(m['dim']),
        defaultLocation: location,
      );
    } on Object {
      return defaults;
    }
  }
}

int _clampDays(Object? v) {
  final n = v is int ? v : (v is num ? v.toInt() : EarthImageryExtraConfig.defaults.lookbackDays);
  if (n < 1) {
    return 1;
  }
  if (n > 60) {
    return 60;
  }
  return n;
}

double _dim(Object? v) {
  final n = v is num ? v.toDouble() : EarthImageryExtraConfig.defaults.dim;
  if (n < 0.05) {
    return 0.05;
  }
  if (n > 0.25) {
    return 0.25;
  }
  return n;
}

int _intField(Object? v, int fallback) {
  if (v is int) {
    return v;
  }
  if (v is num) {
    return v.toInt();
  }
  return fallback;
}

String _stringField(Object? v, String fallback) {
  if (v is String && v.trim().isNotEmpty) {
    return v.trim();
  }
  return fallback;
}
