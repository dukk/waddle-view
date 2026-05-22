/// Global display preference for weather temperature display (ticker, slides).
const String kDisplayWeatherTemperatureUnitKvKey =
    'display.weather.temperature_unit';

/// Celsius.
const String kDisplayWeatherTemperatureUnitC = 'c';

/// Fahrenheit.
const String kDisplayWeatherTemperatureUnitF = 'f';

const String kDefaultDisplayWeatherTemperatureUnit =
    kDisplayWeatherTemperatureUnitF;

/// Normalizes [raw] to [kDisplayWeatherTemperatureUnitC] or [kDisplayWeatherTemperatureUnitF].
String normalizeDisplayWeatherTemperatureUnit(Object? raw) {
  final s = raw == null ? '' : '$raw'.trim().toLowerCase();
  if (s == 'f' || s == 'fahrenheit' || s == 'imperial') {
    return kDisplayWeatherTemperatureUnitF;
  }
  if (s == 'c' || s == 'celsius') {
    return kDisplayWeatherTemperatureUnitC;
  }
  return kDefaultDisplayWeatherTemperatureUnit;
}

/// Reads [kDisplayWeatherTemperatureUnitKvKey] from a KV map.
String displayWeatherTemperatureUnitFromKv(Map<String, String> kv) {
  return normalizeDisplayWeatherTemperatureUnit(
    kv[kDisplayWeatherTemperatureUnitKvKey],
  );
}

bool isFahrenheitTemperatureUnit(String unit) =>
    normalizeDisplayWeatherTemperatureUnit(unit) ==
    kDisplayWeatherTemperatureUnitF;

/// Converts Celsius to Fahrenheit for display.
double celsiusToFahrenheit(double celsius) => celsius * 9 / 5 + 32;

/// Rounds [celsius] for ticker/slide display in the requested [unit].
int formatWeatherTemperatureCelsius(
  double? celsius, {
  required String unit,
}) {
  if (celsius == null) {
    return 0;
  }
  if (isFahrenheitTemperatureUnit(unit)) {
    return celsiusToFahrenheit(celsius).round();
  }
  return celsius.round();
}

String weatherTemperatureSuffix(String unit) =>
    isFahrenheitTemperatureUnit(unit) ? '\u00B0F' : '\u00B0C';
