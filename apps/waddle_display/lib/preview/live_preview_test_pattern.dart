import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Visible 320×180 test JPEG (replaces 1×1 dot in harnesses).
final Uint8List kLivePreviewTestPatternJpeg = _buildTestPatternJpeg();

Uint8List _buildTestPatternJpeg() {
  final image = img.Image(width: 320, height: 180);
  img.fill(image, color: img.ColorRgb8(32, 64, 128));
  img.drawRect(
    image,
    x1: 8,
    y1: 8,
    x2: 311,
    y2: 171,
    color: img.ColorRgb8(200, 210, 230),
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}
