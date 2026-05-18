import 'package:test/test.dart';
import 'package:waddle_shared/persistence/weather_location_category.dart';

void main() {
  group('weatherLocationCategoryFromName', () {
    test('maps US city with state abbreviation to north_america', () {
      expect(weatherLocationCategoryFromName('Seattle, WA'), kWeatherLocationRegionNorthAmerica);
      expect(weatherLocationCategoryFromName('Washington, DC'), kWeatherLocationRegionNorthAmerica);
    });

    test('maps trailing country name to continental region', () {
      expect(
        weatherLocationCategoryFromName('London, United Kingdom'),
        kWeatherLocationRegionEurope,
      );
      expect(weatherLocationCategoryFromName('Tokyo, Japan'), kWeatherLocationRegionAsia);
      expect(weatherLocationCategoryFromName('Toronto, Canada'), kWeatherLocationRegionNorthAmerica);
      expect(weatherLocationCategoryFromName('Sydney, Australia'), kWeatherLocationRegionOceania);
      expect(
        weatherLocationCategoryFromName('São Paulo, Brazil'),
        kWeatherLocationRegionSouthAmerica,
      );
      expect(weatherLocationCategoryFromName('Cairo, Egypt'), kWeatherLocationRegionAfrica);
    });

    test('returns general when country segment missing', () {
      expect(weatherLocationCategoryFromName('Seattle'), 'general');
    });
  });

  group('weatherLocationRegionFromCountrySlug', () {
    test('maps unknown country slug to general', () {
      expect(weatherLocationRegionFromCountrySlug('atlantis'), 'general');
    });
  });
}
