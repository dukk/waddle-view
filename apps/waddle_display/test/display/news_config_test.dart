import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/display/screens/news/news_config.dart';

void main() {
  test('newsQrImageOverlayAlignment maps corner and center modes', () {
    expect(
      newsQrImageOverlayAlignment('image_overlay_bottom_right'),
      Alignment.bottomRight,
    );
    expect(
      newsQrImageOverlayAlignment('image_overlay_top_left'),
      Alignment.topLeft,
    );
    expect(
      newsQrImageOverlayAlignment('image_overlay_top'),
      Alignment.topCenter,
    );
    expect(
      newsQrImageOverlayAlignment('image_overlay_bottom'),
      Alignment.bottomCenter,
    );
    expect(newsQrImageOverlayAlignment('left'), isNull);
    expect(newsQrImageOverlayAlignment('hidden'), isNull);
  });

  test('newsImageAlignment uses focal or top bias', () {
    expect(newsImageAlignment(focalX: 0.5, focalY: 0.5), Alignment.center);
    expect(newsImageAlignment(focalX: 0, focalY: 0), const Alignment(-1, -1));
    expect(newsImageAlignment(), const Alignment(0, -0.3));
  });
}
