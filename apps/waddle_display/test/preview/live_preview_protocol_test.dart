import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/preview/live_preview_protocol.dart';
import 'package:waddle_display/preview/live_preview_test_pattern.dart';

void main() {
  test('encodeLivePreviewFrame prefixes length and format', () {
    final jpeg = kLivePreviewTestPatternJpeg;
    final framed = encodeLivePreviewFrame(jpeg);
    expect(framed.length, kLivePreviewFrameHeaderBytes + jpeg.length);
    final view = ByteData.sublistView(framed);
    expect(view.getUint32(0, Endian.big), jpeg.length);
    expect(view.getUint8(4), kLivePreviewFrameFormatJpeg);
    expect(jpeg.length, greaterThan(500));
  });

  test('extractJpegFramesFromBuffer finds test pattern jpeg', () {
    final frames = extractJpegFramesFromBuffer(kLivePreviewTestPatternJpeg);
    expect(frames, hasLength(1));
    expect(frames.single.length, greaterThan(500));
  });
}
