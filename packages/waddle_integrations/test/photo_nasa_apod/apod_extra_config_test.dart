import 'package:test/test.dart';
import 'package:waddle_integrations/photo_nasa_apod/apod_extra_config.dart';

void main() {
  test('parse defaults for empty config', () {
    final c = ApodExtraConfig.parse(null);
    expect(c.category, 'nasa_apod');
    expect(c.hd, isTrue);
    expect(c.backfillDays, 0);
  });

  test('backfillDays clamped to 7', () {
    final c = ApodExtraConfig.parse('{"backfillDays":99}');
    expect(c.backfillDays, 7);
  });
}
