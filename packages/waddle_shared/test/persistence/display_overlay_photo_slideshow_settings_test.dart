import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/display_overlay_photo_slideshow_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_static_image_settings.dart';

void main() {
  test('parse defaults when empty', () {
    expect(
      PhotoSlideshowOverlaySettings.parse(''),
      PhotoSlideshowOverlaySettings.defaults,
    );
    expect(
      PhotoSlideshowOverlaySettings.parse('{}'),
      PhotoSlideshowOverlaySettings.defaults,
    );
  });

  test('parse clamps placement interval and filters', () {
    final s = PhotoSlideshowOverlaySettings.parseMap({
      'x': 2.0,
      'y': -1.0,
      'scale': 99.0,
      'opacity': 1.5,
      'interval_sec': 99999,
      'category_ids': ['a', 'a', ' ', 'b'],
      'aspect_ratio': 'landscape',
      'min_width': 100,
      'max_width': 4000,
    });
    expect(s.x, 1.0);
    expect(s.y, 0.0);
    expect(s.scale, kStaticImageOverlayScaleMax);
    expect(s.opacity, 1.0);
    expect(s.intervalSec, kPhotoSlideshowIntervalSecMax);
    expect(s.categoryIds, ['a', 'b']);
    expect(s.aspectRatio, kPhotoSlideshowAspectLandscape);
    expect(s.minWidth, 100);
    expect(s.maxWidth, 4000);
    expect(s.isRenderable, isTrue);
    expect(s.hasDimensionOrAspectFilter, isTrue);
  });

  test('parse rejects invalid aspect ratio', () {
    final s = PhotoSlideshowOverlaySettings.parseMap({
      'aspect_ratio': 'invalid',
      'interval_sec': 30,
    });
    expect(s.aspectRatio, kPhotoSlideshowAspectAny);
  });

  test('normalize strips enabled and messages', () {
    final norm = normalizePhotoSlideshowSettingsJsonString(
      '{"enabled":true,"messages":["x"],"interval_sec":45,'
      '"x":0.1,"y":0.2,"scale":0.15,"opacity":0.5,'
      '"category_ids":["nature"],"aspect_ratio":"portrait"}',
    );
    expect(norm, isNotNull);
    final parsed = PhotoSlideshowOverlaySettings.parse(norm!);
    expect(parsed.intervalSec, 45);
    expect(parsed.categoryIds, ['nature']);
    expect(parsed.aspectRatio, kPhotoSlideshowAspectPortrait);
    expect(parsed.opacity, 0.5);
  });

  test('normalize returns null for invalid types', () {
    expect(
      normalizePhotoSlideshowSettingsJsonString('{"interval_sec":"nope"}'),
      isNull,
    );
    expect(
      normalizePhotoSlideshowSettingsJsonString('{"category_ids":"x"}'),
      isNull,
    );
  });
}
