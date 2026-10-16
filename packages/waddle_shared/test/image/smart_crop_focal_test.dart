import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:waddle_shared/image/smart_crop_focal.dart';

Uint8List _pngBytes(img.Image image) =>
    Uint8List.fromList(img.encodePng(image));

void main() {
  test('bright corner blob pulls focal toward that corner', () {
    final image = img.Image(width: 80, height: 80);
    img.fill(image, color: img.ColorRgb8(10, 10, 10));
    // Large high-contrast region in the bottom-right (not upper bias alone).
    for (var y = 45; y < 80; y++) {
      for (var x = 45; x < 80; x++) {
        image.setPixelRgb(x, y, 255, 255, 255);
      }
    }
    final result = analyzeBlobCropMetadata(_pngBytes(image));
    expect(result, isNotNull);
    expect(result!.focalX, greaterThan(0.55));
    expect(result.focalY, greaterThan(0.45));
    expect(result.pixelWidth, 80);
    expect(result.pixelHeight, 80);
  });

  test('skin-tone upper patch sets hasFace and upper focal', () {
    final image = img.Image(width: 100, height: 100);
    img.fill(image, color: img.ColorRgb8(30, 40, 50));
    for (var y = 10; y < 35; y++) {
      for (var x = 40; x < 60; x++) {
        // Skin-like RGB for the heuristic.
        image.setPixelRgb(x, y, 200, 140, 110);
      }
    }
    final result = analyzeBlobCropMetadata(_pngBytes(image));
    expect(result, isNotNull);
    expect(result!.hasFace, isTrue);
    expect(result.focalY, lessThan(0.5));
    expect(result.focalX, closeTo(0.5, 0.2));
  });

  test('preferFace hint without decode short-circuits', () {
    final result = analyzeBlobCropMetadata(
      Uint8List(0),
      hints: const BlobCropProviderHints(
        preferFace: true,
        skipAnalyze: true,
        pixelWidth: 640,
        pixelHeight: 480,
      ),
    );
    expect(result, isNotNull);
    expect(result!.hasFace, isTrue);
    expect(result.focalY, 0.35);
    expect(result.pixelWidth, 640);
  });

  test('alt text can suggest face without skin blob', () {
    final image = img.Image(width: 40, height: 40);
    img.fill(image, color: img.ColorRgb8(80, 80, 80));
    final result = analyzeBlobCropMetadata(
      _pngBytes(image),
      hints: const BlobCropProviderHints(altText: 'portrait of a woman'),
    );
    expect(result, isNotNull);
    expect(result!.hasFace, isTrue);
  });
}
