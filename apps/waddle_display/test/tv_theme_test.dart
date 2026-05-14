import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/theme/tv_theme.dart';

void main() {
  test('TvTheme uses dark high-contrast scheme', () {
    final t = TvTheme.build();
    expect(t.brightness, Brightness.dark);
    expect(t.textTheme.bodyLarge?.fontSize, greaterThanOrEqualTo(18));
  });

  test('TvTheme build honors custom seed color', () {
    final a = TvTheme.build();
    final b = TvTheme.build(seed: const Color(0xFFE91E63));
    expect(b.colorScheme.primary, isNot(equals(a.colorScheme.primary)));
  });
}
