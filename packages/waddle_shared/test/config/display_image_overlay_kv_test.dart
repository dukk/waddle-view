import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/config/display_image_overlay_kv.dart';
import 'package:waddle_shared/persistence/tables.dart';

void main() {
  test('parse defaults when null or empty', () {
    expect(DisplayImageOverlaySettings.parse(null), DisplayImageOverlaySettings.defaults);
    expect(DisplayImageOverlaySettings.parse({}), DisplayImageOverlaySettings.defaults);
  });

  test('parse clamps position scale and opacity', () {
    final s = DisplayImageOverlaySettings.parse({
      'enabled': true,
      'image_blob_key': kOverlayBlobKeyDuckMascot,
      'x': 2.0,
      'y': -1.0,
      'scale': 99.0,
      'opacity': 1.5,
    });
    expect(s.enabled, isTrue);
    expect(s.imageBlobKey, kOverlayBlobKeyDuckMascot);
    expect(s.x, 1.0);
    expect(s.y, 0.0);
    expect(s.scale, kDisplayImageOverlayScaleMax);
    expect(s.opacity, 1.0);
    expect(s.isRenderable, isTrue);
  });

  test('parse rejects invalid blob keys', () {
    final s = DisplayImageOverlaySettings.parse({
      'enabled': true,
      'image_blob_key': 'not-a-valid-key',
    });
    expect(s.imageBlobKey, isEmpty);
    expect(s.isRenderable, isFalse);
  });

  test('encode and decode round-trip', () {
    const original = DisplayImageOverlaySettings(
      enabled: true,
      imageBlobKey: kOverlayBlobKeyDuckMascot,
      x: 0.9,
      y: 0.1,
      scale: 0.15,
      opacity: 0.5,
    );
    final encoded = DisplayImageOverlaySettings.encodeKvValue(original);
    final decoded = DisplayImageOverlaySettings.decodeKvValue(encoded);
    expect(decoded.enabled, isTrue);
    expect(decoded.imageBlobKey, kOverlayBlobKeyDuckMascot);
    expect(decoded.x, 0.9);
    expect(decoded.y, 0.1);
    expect(decoded.scale, 0.15);
    expect(decoded.opacity, 0.5);
  });

  test('toJson omits full opacity and empty blob key', () {
    final json = DisplayImageOverlaySettings.defaults.toJson();
    expect(json['enabled'], isFalse);
    expect(json.containsKey('image_blob_key'), isFalse);
    expect(json.containsKey('opacity'), isFalse);
  });

  test('mergePartial overlays patch fields', () {
    const base = DisplayImageOverlaySettings(
      enabled: false,
      imageBlobKey: kOverlayBlobKeyDuckMascot,
      x: 0.1,
      y: 0.2,
      scale: 0.12,
      opacity: 1.0,
    );
    final merged = base.mergePartial({'enabled': true, 'x': 0.8});
    expect(merged.enabled, isTrue);
    expect(merged.imageBlobKey, kOverlayBlobKeyDuckMascot);
    expect(merged.x, 0.8);
    expect(merged.y, 0.2);
  });
}
