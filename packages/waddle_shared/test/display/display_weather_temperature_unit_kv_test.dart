import 'package:test/test.dart';
import 'package:waddle_shared/display/display_weather_temperature_unit_kv.dart';

void main() {
  group('normalizeCollectedWeatherTempToCelsius', () {
    test('passes through metric/celsius API values', () {
      expect(
        normalizeCollectedWeatherTempToCelsius(19.6, collectUnits: 'metric'),
        19.6,
      );
      expect(
        normalizeCollectedWeatherTempToCelsius(19.6, collectUnits: 'celsius'),
        19.6,
      );
    });

    test('converts imperial/fahrenheit API values to Celsius', () {
      expect(
        normalizeCollectedWeatherTempToCelsius(72, collectUnits: 'imperial'),
        closeTo(22.222, 0.001),
      );
      expect(
        normalizeCollectedWeatherTempToCelsius(72, collectUnits: 'fahrenheit'),
        closeTo(22.222, 0.001),
      );
      expect(
        normalizeCollectedWeatherTempToCelsius(72, collectUnits: 'f'),
        closeTo(22.222, 0.001),
      );
    });

    test('returns null for null input', () {
      expect(
        normalizeCollectedWeatherTempToCelsius(null, collectUnits: 'imperial'),
        isNull,
      );
    });
  });

  group('formatWeatherTemperatureCelsius', () {
    test('formats stored Celsius for Fahrenheit display', () {
      expect(
        formatWeatherTemperatureCelsius(
          19.6,
          unit: kDisplayWeatherTemperatureUnitF,
        ),
        67,
      );
      expect(
        '${formatWeatherTemperatureCelsius(19.6, unit: kDisplayWeatherTemperatureUnitF)}'
            '${weatherTemperatureSuffix(kDisplayWeatherTemperatureUnitF)}',
        '67°F',
      );
    });

    test('formats stored Celsius for Celsius display', () {
      expect(
        formatWeatherTemperatureCelsius(
          19.6,
          unit: kDisplayWeatherTemperatureUnitC,
        ),
        20,
      );
    });
  });
}
