import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/display_overlay_static_image_settings.dart';
import 'package:waddle_shared/persistence/tables.dart';

void main() {
  test('parse defaults when empty', () {
    expect(StaticImageOverlaySettings.parse(''), StaticImageOverlaySettings.defaults);
    expect(StaticImageOverlaySettings.parse('{}'), StaticImageOverlaySettings.defaults);
  });

  test('parse clamps position scale and opacity', () {
    final s = StaticImageOverlaySettings.parseMap({
      'image_blob_key': kOverlayBlobKeyDuckMascot,
      'x': 2.0,
      'y': -1.0,
      'scale': 99.0,
      'opacity': 1.5,
    });
    expect(s.imageBlobKey, kOverlayBlobKeyDuckMascot);
    expect(s.x, 1.0);
    expect(s.y, 0.0);
    expect(s.scale, kStaticImageOverlayScaleMax);
    expect(s.opacity, 1.0);
    expect(s.isRenderable, isTrue);
  });

  test('parse rejects invalid blob keys', () {
    final s = StaticImageOverlaySettings.parseMap({
      'image_blob_key': 'not-a-valid-key',
    });
    expect(s.imageBlobKey, isEmpty);
    expect(s.isRenderable, isFalse);
  });

  test('normalize strips enabled and messages', () {
    final norm = normalizeStaticImageSettingsJsonString(
      '{"enabled":true,"messages":["x"],"image_blob_key":"$kOverlayBlobKeyDuckMascot",'
      '"x":0.1,"y":0.2,"scale":0.15,"opacity":0.5}',
    );
    expect(norm, isNotNull);
    final parsed = StaticImageOverlaySettings.parse(norm!);
    expect(parsed.imageBlobKey, kOverlayBlobKeyDuckMascot);
    expect(parsed.opacity, 0.5);
  });

  test('parseLegacyDisplayImageOverlayKv requires enabled and valid blob', () {
    expect(parseLegacyDisplayImageOverlayKv(null), isNull);
    expect(
      parseLegacyDisplayImageOverlayKv('{"enabled":false}'),
      isNull,
    );
    final s = parseLegacyDisplayImageOverlayKv(
      '{"enabled":true,"image_blob_key":"$kOverlayBlobKeyDuckMascot"}',
    );
    expect(s?.imageBlobKey, kOverlayBlobKeyDuckMascot);
  });
}
