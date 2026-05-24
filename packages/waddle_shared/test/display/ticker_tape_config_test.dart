import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/config/controller_datetime_format_kv.dart';
import 'package:waddle_shared/display/display_weather_temperature_unit_kv.dart';
import 'package:waddle_shared/display/ticker_tape_config.dart';

void main() {
  test('parseTickerTapeTimeConfig reads preset date order zone and prefix', () {
    final cfg = parseTickerTapeTimeConfig('''
{"timeFormatPreset":"12h_hm_tt","dateOrder":"dmy","timeZone":"Europe/London","labelPrefix":"London"}
''');
    expect(cfg.timeFormatPreset, '12h_hm_tt');
    expect(cfg.dateOrder, 'dmy');
    expect(cfg.timeZone, 'Europe/London');
    expect(cfg.labelPrefix, 'London');
  });

  test(
    'parseTickerTapeTimeConfig leaves preset and date order null when absent',
    () {
      final cfg = parseTickerTapeTimeConfig('{}');
      expect(cfg.timeFormatPreset, isNull);
      expect(cfg.dateOrder, isNull);
      expect(cfg.timeZone, isNull);
    },
  );

  test('parseTickerTapeTimeConfig ignores invalid dateOrder', () {
    final cfg = parseTickerTapeTimeConfig('{"dateOrder":"invalid"}');
    expect(cfg.dateOrder, isNull);
  });

  test('effectiveTickerDateOrder follows controller.date_order', () {
    expect(
      effectiveTickerDateOrder(
        kv: const {},
        tape: const TickerTapeTimeConfig(),
      ),
      kDefaultControllerDateOrder,
    );
    expect(
      effectiveTickerDateOrder(
        kv: {kControllerDateOrderKvKey: kControllerDateOrderDmy},
        tape: const TickerTapeTimeConfig(),
      ),
      kControllerDateOrderDmy,
    );
    expect(
      effectiveTickerDateOrder(
        kv: {kControllerDateOrderKvKey: kControllerDateOrderMdy},
        tape: const TickerTapeTimeConfig(dateOrder: kControllerDateOrderYmd),
      ),
      kControllerDateOrderYmd,
    );
  });

  test(
    'effectiveTickerTimeFormatPresetOverride returns null when preset absent',
    () {
      expect(
        effectiveTickerTimeFormatPresetOverride(const TickerTapeTimeConfig()),
        isNull,
      );
      expect(
        effectiveTickerTimeFormatPresetOverride(
          const TickerTapeTimeConfig(timeFormatPreset: '12h_hm_tt'),
        ),
        '12h_hm_tt',
      );
    },
  );

  test('effectiveTickerTimeFormatPreset follows controller.time_format', () {
    expect(
      effectiveTickerTimeFormatPreset(
        kv: const {},
        tape: const TickerTapeTimeConfig(),
      ),
      '12h_hms_ampm',
    );
    expect(
      effectiveTickerTimeFormatPreset(
        kv: {kControllerTimeFormatKvKey: kControllerTimeFormat24h},
        tape: const TickerTapeTimeConfig(),
      ),
      '24h_hms',
    );
    expect(
      effectiveTickerTimeFormatPreset(
        kv: {kControllerTimeFormatKvKey: kControllerTimeFormat24h},
        tape: const TickerTapeTimeConfig(timeFormatPreset: '12h_hm_tt'),
      ),
      '12h_hm_tt',
    );
  });

  test('parseTickerTapeWeatherConfig and stock symbol ids', () {
    final w = parseTickerTapeWeatherConfig(
      '{"locationId":"sea","temperatureUnit":"f"}',
    );
    expect(w.locationId, 'sea');
    expect(w.temperatureUnit, 'f');

    expect(parseTickerTapeStockSymbolIds('{"symbolIds":["a","b"]}'), [
      'a',
      'b',
    ]);
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
    expect(weatherIconCodeFromBlobKey('weather/icons/10d'), '10d');
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
