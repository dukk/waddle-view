import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/theme/display_theme.dart';
import 'package:waddle_view/theme/ticker_marquee_style.dart';

void main() {
  test('DisplayTheme matches calendar-style dark palette', () {
    final t = DisplayTheme.build();
    final palette = t.extension<PaletteTertiaryLayers>();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, NavyCoralPalette.background);
    expect(t.colorScheme.surface, NavyCoralPalette.background);
    expect(t.colorScheme.onSurface, NavyCoralPalette.primaryText);
    expect(
      t.colorScheme.surfaceContainerHighest,
      NavyCoralPalette.footerBar,
    );
    expect(t.colorScheme.onSurfaceVariant, NavyCoralPalette.mutedText);
    expect(t.colorScheme.primary, NavyCoralPalette.primary);
    expect(t.colorScheme.secondary, NavyCoralPalette.accents[0]);
    expect(t.colorScheme.tertiary, NavyCoralPalette.accents[1]);
    expect(t.colorScheme.outline, NavyCoralPalette.accents[2]);
    expect(palette, isNotNull);
    expect(palette!.colorOrder, NavyCoralPalette.orderedPalette);
    expect(palette.iconColor, NavyCoralPalette.dustyDenim);
    expect(palette.accent1, NavyCoralPalette.accents[0]);
    expect(palette.accent2, NavyCoralPalette.accents[1]);
    expect(palette.accent3, NavyCoralPalette.accents[2]);
    expect(
      palette.primaryPairGradient.colors,
      [NavyCoralPalette.inkBlack, NavyCoralPalette.prussianBlue],
    );
    expect(
      palette.secondaryPairGradient.colors,
      [NavyCoralPalette.duskBlue, NavyCoralPalette.dustyDenim],
    );
    expect(t.iconTheme.color, NavyCoralPalette.dustyDenim);
    for (final color in NavyCoralPalette.orderedPalette) {
      expect(palette.tertiaryLayersFor(color), hasLength(4));
    }
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

  test('DisplayTheme.buildForId and buildFromKvValue resolve presets', () {
    final graphite = DisplayTheme.buildForId(kDisplayThemeGraphiteAmber);
    final graphitePalette = graphite.extension<PaletteTertiaryLayers>();
    expect(graphite.brightness, Brightness.dark);
    expect(graphitePalette, isNotNull);
    expect(graphitePalette!.primaryPairGradient.colors, hasLength(2));
    expect(graphitePalette.secondaryPairGradient.colors, hasLength(2));
    expect(
      DisplayTheme.buildFromKvValue(kDisplayThemeNavyCoral).brightness,
      Brightness.dark,
    );
    expect(
      DisplayTheme.buildFromKvValue(null).brightness,
      DisplayTheme.build().brightness,
    );
  });

  test('DisplayTextScaler equality and deprecated textScaleFactor', () {
    const a = DisplayTextScaler(TextScaler.linear(2), 1.5);
    const b = DisplayTextScaler(TextScaler.linear(2), 1.5);
    const c = DisplayTextScaler(TextScaler.linear(2), 2.0);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
    expect(a.textScaleFactor, closeTo(3.0, 1e-9));
  });
}
