import 'package:test/test.dart';
import 'package:waddle_integrations/weather_openmeteo/wmo_weather_code.dart';

void main() {
  test('wmoWeatherDescription covers clear and rain', () {
    expect(wmoWeatherDescription(0), 'Clear sky');
    expect(wmoWeatherDescription(63), 'Moderate rain');
    expect(wmoWeatherDescription(999), 'Unknown');
  });

  test('wmoWeatherOpenWeatherIcon maps codes for slide icons', () {
    expect(wmoWeatherOpenWeatherIcon(0), '01d');
    expect(wmoWeatherOpenWeatherIcon(3), '04d');
    expect(wmoWeatherOpenWeatherIcon(61), '10d');
    expect(wmoWeatherOpenWeatherIcon(95), '11d');
  });
}
