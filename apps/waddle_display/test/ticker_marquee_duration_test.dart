import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/ticker/ticker_marquee_duration.dart';

void main() {
  test('marqueeScrollDuration scales width by pixels per second', () {
    expect(
      marqueeScrollDuration(contentWidthPx: 100, pixelsPerSecond: 50)
          .inMilliseconds,
      2000,
    );
  });

  test('marqueeScrollDuration clamps to at least 1ms', () {
    expect(
      marqueeScrollDuration(contentWidthPx: 0, pixelsPerSecond: 100)
          .inMilliseconds,
      1,
    );
  });
}
