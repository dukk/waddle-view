import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/theme/tv_theme.dart';

void main() {
  test('TvTheme uses dark high-contrast scheme', () {
    final t = TvTheme.build();
    expect(t.brightness, Brightness.dark);
    expect(t.textTheme.bodyLarge?.fontSize, greaterThanOrEqualTo(18));
  });
}
