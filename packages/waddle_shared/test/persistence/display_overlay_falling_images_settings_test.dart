import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_falling_images_settings.dart';

void main() {
  group('FallingImagesScheduleSettings.parse', () {
    test('uses defaults for empty config', () {
      final s = FallingImagesScheduleSettings.parse('{}');
      expect(s.imageBlobKeys, isEmpty);
      expect(s.dropIntervalSec, FallingImagesScheduleSettings.defaults.dropIntervalSec);
      expect(s.fallSpeed, FallingImagesScheduleSettings.defaults.fallSpeed);
    });

    test('parses blob keys and clamps motion', () {
      final s = FallingImagesScheduleSettings.parse(
        '{"image_blob_keys":["overlay/a/x.png","overlay/b/y.jpg"],'
        '"drop_interval_sec":5,"fall_speed":9}',
      );
      expect(s.imageBlobKeys, ['overlay/a/x.png', 'overlay/b/y.jpg']);
      expect(s.dropIntervalSec, 15);
      expect(s.fallSpeed, 1.0);
    });
  });

  group('normalizeFallingImagesConfigJsonString', () {
    test('accepts valid config', () {
      final out = normalizeFallingImagesConfigJsonString(
        '{"image_blob_keys":["overlay/pool/1"],"drop_interval_sec":60,"fall_speed":0.2}',
      );
      expect(out, isNotNull);
      expect(out, contains('overlay/pool/1'));
    });

    test('rejects unknown keys', () {
      expect(
        normalizeFallingImagesConfigJsonString('{"extra":1}'),
        isNull,
      );
    });

    test('rejects invalid blob key prefix', () {
      expect(
        normalizeFallingImagesConfigJsonString(
          '{"image_blob_keys":["photos/x"]}',
        ),
        isNull,
      );
    });
  });
}
