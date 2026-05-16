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

  test('TickerMarqueeStyle lerp returns this when other is null', () {
    const a = TickerMarqueeStyle.fallback();
    expect(identical(a.lerp(null, 0.25), a), isTrue);
  });

  test('fromTvTheme uses TextStyle fallback when titleLarge missing', () {
    const emptyText = TextTheme();
    final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
    final s = TickerMarqueeStyle.fromTvTheme(emptyText, scheme);
    expect(s.rssTitleStyle.fontWeight, FontWeight.w700);
    expect(s.rssSourceStyle.fontStyle, FontStyle.italic);
  });

  test('copyWith replaces only provided TextStyle fields', () {
    const a = TickerMarqueeStyle.fallback();
    final b = a.copyWith(rssTitleStyle: const TextStyle(fontSize: 42)) as TickerMarqueeStyle;
    expect(b.rssTitleStyle.fontSize, 42);
    expect(b.rssSourceStyle, a.rssSourceStyle);
    expect(b.rssSummaryStyle, a.rssSummaryStyle);
  });

  test('applyTickerMarqueeStyle works on ThemeData without prior ticker style',
      () {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    );
    final merged = applyTickerMarqueeStyle(base);
    expect(merged.extension<TickerMarqueeStyle>(), isNotNull);
  });
}
