import 'dart:convert';

const String kDefaultWeatherUnits = 'imperial';
const String kDefaultWeatherLanguage = 'en';
const String kDefaultWeatherLocationName = 'Default';
const double kDefaultWeatherLatitude = 40.7128;
const double kDefaultWeatherLongitude = -74.0060;
const int kDefaultWeatherHourlyCount = 6;

class WeatherLocationConfig {
  const WeatherLocationConfig({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}

class WeatherProviderExtraConfig {
  const WeatherProviderExtraConfig({
    required this.units,
    required this.language,
    required this.defaultLocation,
    required this.hourlyCount,
  });

  final String units;
  final String language;
  final WeatherLocationConfig defaultLocation;
  final int hourlyCount;

  static WeatherProviderExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const WeatherProviderExtraConfig(
        units: kDefaultWeatherUnits,
        language: kDefaultWeatherLanguage,
        defaultLocation: WeatherLocationConfig(
          name: kDefaultWeatherLocationName,
          latitude: kDefaultWeatherLatitude,
          longitude: kDefaultWeatherLongitude,
        ),
        hourlyCount: kDefaultWeatherHourlyCount,
      );
    }
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map) {
        return parse(null);
      }
      final m = Map<String, dynamic>.from(decoded);
      final location = _parseLocation(m['defaultLocation']);
      return WeatherProviderExtraConfig(
        units: (m['units'] as String?)?.trim().isNotEmpty == true
            ? (m['units'] as String).trim()
            : kDefaultWeatherUnits,
        language: (m['lang'] as String?)?.trim().isNotEmpty == true
            ? (m['lang'] as String).trim()
            : kDefaultWeatherLanguage,
        defaultLocation: location,
        hourlyCount: (m['hourlyCount'] as num?)?.toInt() ?? kDefaultWeatherHourlyCount,
      );
    } on Object {
      return parse(null);
    }
  }

  static WeatherLocationConfig _parseLocation(Object? raw) {
    if (raw is! Map) {
      return const WeatherLocationConfig(
        name: kDefaultWeatherLocationName,
        latitude: kDefaultWeatherLatitude,
        longitude: kDefaultWeatherLongitude,
      );
    }
    final m = Map<String, dynamic>.from(raw);
    final lat = (m['lat'] as num?)?.toDouble();
    final lon = (m['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) {
      return const WeatherLocationConfig(
        name: kDefaultWeatherLocationName,
        latitude: kDefaultWeatherLatitude,
        longitude: kDefaultWeatherLongitude,
      );
    }
    final name = (m['name'] as String?)?.trim();
    return WeatherLocationConfig(
      name: (name == null || name.isEmpty) ? 'LatLon($lat,$lon)' : name,
      latitude: lat,
      longitude: lon,
    );
  }
}
