import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_data_providers/media_bing_iotd/bing_image_of_day_extra_config.dart';

void main() {
  test('parse returns defaults for null, empty, and invalid JSON', () {
    expect(BingImageOfDayExtraConfig.parse(null).retentionDays, 1);
    expect(BingImageOfDayExtraConfig.parse(null).market, 'en-US');
    expect(BingImageOfDayExtraConfig.parse(null).resolution, 'UHD');
    expect(BingImageOfDayExtraConfig.parse(null).category, 'bing');

    expect(BingImageOfDayExtraConfig.parse('').resolution, 'UHD');
    expect(BingImageOfDayExtraConfig.parse('{').retentionDays, 1);
  });

  test('parse reads retentionDays, market, resolution, category', () {
    final c = BingImageOfDayExtraConfig.parse(
      '{"retentionDays":3,"market":"en-GB","resolution":"1920x1080","category":"bing_wall"}',
    );
    expect(c.retentionDays, 3);
    expect(c.market, 'en-GB');
    expect(c.resolution, '1920x1080');
    expect(c.category, 'bing_wall');
  });

  test('unknown resolution falls back to UHD', () {
    final c = BingImageOfDayExtraConfig.parse('{"resolution":"9999x9999"}');
    expect(c.resolution, 'UHD');
  });

  test('retentionDays zero or negative is preserved for provider no-prune', () {
    expect(BingImageOfDayExtraConfig.parse('{"retentionDays":0}').retentionDays, 0);
    expect(BingImageOfDayExtraConfig.parse('{"retentionDays":-1}').retentionDays, -1);
  });

  test('kBingWallpaperResolutionSuffixes contains planned keys', () {
    expect(kBingWallpaperResolutionSuffixes, contains('UHD'));
    expect(kBingWallpaperResolutionSuffixes, contains('1080x1920'));
  });
}
