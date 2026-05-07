import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/theme/ticker_marquee_style.dart';

@immutable
class _MarkerExtension extends ThemeExtension<_MarkerExtension> {
  const _MarkerExtension({required this.value});

  final int value;

  @override
  _MarkerExtension copyWith({int? value}) =>
      _MarkerExtension(value: value ?? this.value);

  @override
  _MarkerExtension lerp(ThemeExtension<_MarkerExtension>? other, double t) =>
      this;
}

void main() {
  test('applyTickerMarqueeStyle keeps other extensions and replaces ticker', () {
    final base = ThemeData.light().copyWith(
      extensions: <ThemeExtension<dynamic>>[
        const _MarkerExtension(value: 7),
        TickerMarqueeStyle.fromTvTheme(
          ThemeData.light().textTheme,
          ThemeData.light().colorScheme,
        ),
      ],
    );
    final merged = applyTickerMarqueeStyle(base);
    expect(merged.extension<_MarkerExtension>()?.value, 7);
    expect(merged.extension<TickerMarqueeStyle>(), isNotNull);
  });

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
