import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/ticker/ticker_marquee_duration.dart';

void main() {
  test('marqueeScrollDuration scales scroll distance by pixels per second', () {
    expect(
      marqueeScrollDuration(scrollDistancePx: 100, pixelsPerSecond: 50)
          .inMilliseconds,
      2000,
    );
  });

  test('marqueeScrollDuration includes viewport in typical marquee distance', () {
    expect(
      marqueeScrollDuration(
        scrollDistancePx: 500 + 800,
        pixelsPerSecond: 80,
      ).inMilliseconds,
      16250,
    );
  });

  test('marqueeScrollDuration clamps to at least 1ms', () {
    expect(
      marqueeScrollDuration(scrollDistancePx: 0, pixelsPerSecond: 100)
          .inMilliseconds,
      1,
    );
  });
}
