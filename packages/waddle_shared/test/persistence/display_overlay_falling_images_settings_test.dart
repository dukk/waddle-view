import 'dart:convert';

import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_falling_images_settings.dart';

void main() {
  group('FallingImagesScheduleSettings.parse', () {
    test('uses defaults for empty config', () {
      final s = FallingImagesScheduleSettings.parse('{}');
      expect(s.imageBlobKeys, isEmpty);
      expect(s.dropIntervalSec, FallingImagesScheduleSettings.defaults.dropIntervalSec);
      expect(s.fallSpeed, FallingImagesScheduleSettings.defaults.fallSpeed);
      expect(s.imageScale, FallingImagesScheduleSettings.defaults.imageScale);
      expect(s.scaleJitter, FallingImagesScheduleSettings.defaults.scaleJitter);
    });

    test('parses blob keys and clamps motion and scale', () {
      final s = FallingImagesScheduleSettings.parse(
        '{"image_blob_keys":["overlay/a/x.png","overlay/b/y.jpg"],'
        '"drop_interval_sec":5,"fall_speed":9,'
        '"image_scale":0.5,"scale_jitter":2}',
      );
      expect(s.imageBlobKeys, ['overlay/a/x.png', 'overlay/b/y.jpg']);
      expect(s.dropIntervalSec, 15);
      expect(s.fallSpeed, 1.0);
      expect(s.imageScale, 0.35);
      expect(s.scaleJitter, 1.0);
    });

    test('clamps image_scale to minimum', () {
      final s = FallingImagesScheduleSettings.parse('{"image_scale":0.01}');
      expect(s.imageScale, kFallingImagesImageScaleMin);
    });
  });

  group('normalizeFallingImagesConfigJsonString', () {
    test('accepts valid config', () {
      final out = normalizeFallingImagesConfigJsonString(
        '{"image_blob_keys":["overlay/pool/1"],"drop_interval_sec":60,'
        '"fall_speed":0.2,"image_scale":0.15,"scale_jitter":0.25}',
      );
      expect(out, isNotNull);
      final map = jsonDecode(out!) as Map<String, dynamic>;
      expect(map['image_blob_keys'], ['overlay/pool/1']);
      expect(map['drop_interval_sec'], 60);
      expect(map['fall_speed'], 0.2);
      expect(map['image_scale'], 0.15);
      expect(map['scale_jitter'], 0.25);
    });

    test('rejects unknown keys', () {
      expect(
        normalizeFallingImagesConfigJsonString('{"extra":1}'),
        isNull,
      );
    });

    test('rejects messages key', () {
      expect(
        normalizeFallingImagesConfigJsonString(
          '{"messages":["hi"],"image_blob_keys":["overlay/pool/1"]}',
        ),
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
