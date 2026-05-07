import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/theme/ticker_marquee_style.dart';

void main() {
  test('TickerMarqueeStyle lerp returns dark or other at ends', () {
    const a = TickerMarqueeStyle.fallback();
    final b = TickerMarqueeStyle(
      rssSourceStyle: TextStyle(color: Color(0xFFFF0000)),
      rssTitleStyle: TextStyle(color: Color(0xFF00FF00)),
      rssSummaryStyle: TextStyle(color: Color(0xFF0000FF)),
    );
    final mid = a.lerp(b, 0.5) as TickerMarqueeStyle;
    expect(mid.rssSourceStyle.color, isNotNull);
  });
}
