import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/theme/display_theme.dart';
import 'package:waddle_view/theme/ticker_marquee_style.dart';

void main() {
  test('DisplayTheme matches calendar-style dark palette', () {
    final t = DisplayTheme.build();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, DisplayThemeColors.background);
    expect(t.colorScheme.surface, DisplayThemeColors.background);
    expect(t.colorScheme.onSurface, DisplayThemeColors.primaryText);
    expect(t.colorScheme.surfaceContainerHighest, DisplayThemeColors.footerBar);
    expect(t.colorScheme.onSurfaceVariant, DisplayThemeColors.mutedText);
    expect(t.colorScheme.primary, DisplayThemeColors.accent);
    expect(t.colorScheme.outline, DisplayThemeColors.accent);
    expect(t.textTheme.bodyLarge?.fontSize, greaterThanOrEqualTo(18));
    expect(t.extension<TickerMarqueeStyle>(), isA<TickerMarqueeStyle>());
  });
}
