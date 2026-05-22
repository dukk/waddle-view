import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/display/display_weather_temperature_unit_kv.dart';
import 'package:waddle_shared/display/ticker_tape_config.dart';

void main() {
  test('parseTickerTapeTimeConfig reads preset zone and prefix', () {
    final cfg = parseTickerTapeTimeConfig('''
{"timeFormatPreset":"12h_hm_tt","timeZone":"Europe/London","labelPrefix":"London"}
''');
    expect(cfg.timeFormatPreset, '12h_hm_tt');
    expect(cfg.timeZone, 'Europe/London');
    expect(cfg.labelPrefix, 'London');
  });

  test('parseTickerTapeTimeConfig defaults preset', () {
    final cfg = parseTickerTapeTimeConfig('{}');
    expect(cfg.timeFormatPreset, kDefaultTickerTimeFormatPreset);
    expect(cfg.timeZone, isNull);
  });

  test('parseTickerTapeWeatherConfig and stock symbol ids', () {
    final w = parseTickerTapeWeatherConfig(
      '{"locationId":"sea","temperatureUnit":"f"}',
    );
    expect(w.locationId, 'sea');
    expect(w.temperatureUnit, 'f');

    expect(
      parseTickerTapeStockSymbolIds('{"symbolIds":["a","b"]}'),
      ['a', 'b'],
    );
    expect(parseTickerTapeStockSymbolIds('{}'), isNull);
  });

  test('parseTickerTapeNewsConfig', () {
    final n = parseTickerTapeNewsConfig(
      '{"categoryId":"news","prefixFeedName":false}',
    );
    expect(n.categoryId, 'news');
    expect(n.prefixFeedName, isFalse);
  });

  test('weatherIconCodeFromBlobKey', () {
    expect(
      weatherIconCodeFromBlobKey('weather/icons/10d'),
      '10d',
    );
    expect(weatherIconCodeFromBlobKey(null), isNull);
  });

  test('normalizeDisplayWeatherTemperatureUnit', () {
    expect(
      normalizeDisplayWeatherTemperatureUnit(null),
      kDefaultDisplayWeatherTemperatureUnit,
    );
    expect(
      normalizeDisplayWeatherTemperatureUnit(''),
      kDefaultDisplayWeatherTemperatureUnit,
    );
    expect(
      normalizeDisplayWeatherTemperatureUnit('fahrenheit'),
      kDisplayWeatherTemperatureUnitF,
    );
    expect(
      normalizeDisplayWeatherTemperatureUnit('c'),
      kDisplayWeatherTemperatureUnitC,
    );
    expect(
      formatWeatherTemperatureCelsius(0, unit: kDisplayWeatherTemperatureUnitF),
      32,
    );
    expect(
      weatherTemperatureSuffix(kDisplayWeatherTemperatureUnitC),
      '\u00B0C',
    );
  });
}
