import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_data_providers/media_pexels/pexels_provider_extra_config.dart';

void main() {
  test('parse uses defaults for null or invalid json', () {
    final a = PexelsProviderExtraConfig.parse(null);
    expect(a.maxPhotos, 100);
    expect(a.photosPerHour, 2);
    expect(a.minVideoSeconds, 11);
    expect(a.maxVideoSeconds, 29);
    expect(a.sources, isEmpty);

    final b = PexelsProviderExtraConfig.parse('not json');
    expect(b.sources, isEmpty);
  });

  test('parse reads sources and numeric overrides', () {
    final c = PexelsProviderExtraConfig.parse(
      '{"maxPhotos":3,"photosPerHour":5,"sources":['
      '{"query":"a","category":"b"},'
      '{"invalid":true},'
      '{"query":"","category":"x"}'
      ']}',
    );
    expect(c.maxPhotos, 3);
    expect(c.photosPerHour, 5);
    expect(c.sources.length, 1);
    expect(c.sources.single.query, 'a');
    expect(c.sources.single.category, 'b');
  });
}
