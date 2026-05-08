import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/data/providers/weather/weather_provider_extra_config.dart';

void main() {
  test('defaults when extra empty', () {
    final c = WeatherProviderExtraConfig.parse(null);
    expect(c.units, kDefaultWeatherUnits);
    expect(c.language, kDefaultWeatherLanguage);
    expect(c.defaultLocation.name, kDefaultWeatherLocationName);
    expect(c.defaultLocation.latitude, closeTo(kDefaultWeatherLatitude, 0.000001));
    expect(c.defaultLocation.longitude, closeTo(kDefaultWeatherLongitude, 0.000001));
    expect(c.hourlyCount, kDefaultWeatherHourlyCount);
  });

  test('parse reads configured location and options', () {
    final c = WeatherProviderExtraConfig.parse(
      '{"units":"imperial","lang":"es","hourlyCount":8,'
      '"defaultLocation":{"name":"Denver","lat":39.7392,"lon":-104.9903}}',
    );
    expect(c.units, 'imperial');
    expect(c.language, 'es');
    expect(c.hourlyCount, 8);
    expect(c.defaultLocation.name, 'Denver');
    expect(c.defaultLocation.latitude, closeTo(39.7392, 0.000001));
    expect(c.defaultLocation.longitude, closeTo(-104.9903, 0.000001));
  });
}
