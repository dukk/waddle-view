import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/theme/display_theme.dart';
import 'package:waddle_view/theme/ticker_marquee_style.dart';

void main() {
  test('DisplayTheme matches calendar-style dark palette', () {
    final t = DisplayTheme.build();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, NavyCoralPalette.background);
    expect(t.colorScheme.surface, NavyCoralPalette.background);
    expect(t.colorScheme.onSurface, NavyCoralPalette.primaryText);
    expect(
      t.colorScheme.surfaceContainerHighest,
      NavyCoralPalette.footerBar,
    );
    expect(t.colorScheme.onSurfaceVariant, NavyCoralPalette.mutedText);
    expect(t.colorScheme.primary, NavyCoralPalette.accent);
    expect(t.colorScheme.outline, NavyCoralPalette.accent);
    expect(t.textTheme.bodyLarge?.fontSize, greaterThanOrEqualTo(18));
    expect(t.extension<TickerMarqueeStyle>(), isA<TickerMarqueeStyle>());
  });

  test('DisplayTextScaler composes with platform TextScaler', () {
    const platform = TextScaler.linear(1.5);
    final combined = DisplayTheme.wrapTextScaler(platform);
    expect(
      combined.scale(10),
      closeTo(10 * 1.5 * DisplayTheme.textScale, 1e-9),
    );
  });
}
