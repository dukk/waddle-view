import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_data_providers/media_flickr/flickr_media_extra_config.dart';

void main() {
  test('defaults for null config', () {
    final cfg = FlickrMediaExtraConfig.parse(null);
    expect(cfg.groupIds, isEmpty);
    expect(cfg.category, 'flickr');
    expect(cfg.perPollLimit, 20);
    expect(cfg.sort, 'date-posted-desc');
  });

  test('parses explicit values', () {
    final cfg = FlickrMediaExtraConfig.parse(
      '{"groupIds":["g1","g2"],"category":"family","perPollLimit":7,"sort":"interestingness-desc"}',
    );
    expect(cfg.groupIds, ['g1', 'g2']);
    expect(cfg.category, 'family');
    expect(cfg.perPollLimit, 7);
    expect(cfg.sort, 'interestingness-desc');
  });

  test('drops blank group ids and falls back for invalid numbers', () {
    final cfg = FlickrMediaExtraConfig.parse(
      '{"groupIds":["g1","","  "],"perPollLimit":0}',
    );
    expect(cfg.groupIds, ['g1']);
    expect(cfg.perPollLimit, 20);
  });
}
