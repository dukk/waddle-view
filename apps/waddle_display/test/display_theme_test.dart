import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/theme/display_theme.dart';
import 'package:waddle_display/theme/ticker_marquee_style.dart';

String _hex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

List<String> _controllerPreviewHex(ThemeData theme, PaletteTertiaryLayers ext) {
  final seen = <String>{};
  final out = <String>[];
  void add(Color c) {
    final h = _hex(c);
    if (seen.add(h)) out.add(h);
  }

  for (final c in ext.displayBackgroundFill.gradientColors) {
    add(c);
  }
  add(theme.colorScheme.onPrimaryContainer);
  for (final c in ext.primaryContainerFill.gradientColors) {
    add(c);
  }
  add(theme.colorScheme.onSecondaryContainer);
  for (final c in ext.secondaryContainerFill.gradientColors) {
    add(c);
  }
  add(ext.accent1);
  add(ext.accent2);
  add(ext.accent3);
  add(ext.accent4);
  return out;
}

void main() {
  test('DisplayTheme matches calendar-style dark palette', () {
    final t = DisplayTheme.build();
    final palette = t.extension<PaletteTertiaryLayers>();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, NavyCoralPalette.displayBackgroundFill.resolveColor());
    expect(t.colorScheme.surface, NavyCoralPalette.background);
    expect(t.colorScheme.onSurface, NavyCoralPalette.primaryText);
    expect(
      t.colorScheme.primaryContainer,
      NavyCoralPalette.primaryContainerBackground,
    );
    expect(
      t.colorScheme.onPrimaryContainer,
      NavyCoralPalette.primaryContainerForeground,
    );
    expect(
      t.colorScheme.secondaryContainer,
      NavyCoralPalette.secondaryContainerBackground,
    );
    expect(
      t.colorScheme.onSecondaryContainer,
      NavyCoralPalette.secondaryContainerForeground,
    );
    expect(
      t.colorScheme.surfaceContainerHighest,
      NavyCoralPalette.footerBar,
    );
    expect(t.colorScheme.onSurfaceVariant, NavyCoralPalette.mutedText);
    expect(t.colorScheme.primary, NavyCoralPalette.primary);
    expect(t.colorScheme.secondary, NavyCoralPalette.accents[0]);
    expect(t.colorScheme.tertiary, NavyCoralPalette.accents[1]);
    expect(t.colorScheme.outline, NavyCoralPalette.accents[2]);
    expect(t.colorScheme.tertiaryContainer, NavyCoralPalette.accents[3]);
    expect(palette, isNotNull);
    expect(palette!.colorOrder, NavyCoralPalette.orderedPalette);
    expect(palette.iconColor, NavyCoralPalette.dustyDenim);
    expect(palette.accent1, NavyCoralPalette.accents[0]);
    expect(palette.accent2, NavyCoralPalette.accents[1]);
    expect(palette.accent3, NavyCoralPalette.accents[2]);
    expect(palette.accent4, NavyCoralPalette.accents[3]);
    expect(
      palette.primaryPairGradient.colors,
      NavyCoralPalette.primaryContainerFill.gradientColors,
    );
    expect(
      palette.secondaryPairGradient.colors,
      NavyCoralPalette.secondaryContainerFill.gradientColors,
    );
    expect(
      palette.displayBackgroundFill.gradientColors,
      NavyCoralPalette.displayBackgroundFill.gradientColors,
    );
    expect(t.iconTheme.color, NavyCoralPalette.dustyDenim);
    for (final color in NavyCoralPalette.orderedPalette) {
      expect(palette.tertiaryLayersFor(color), hasLength(4));
    }
    expect(t.textTheme.bodyLarge?.fontSize, greaterThanOrEqualTo(18));
    expect(t.extension<TickerMarqueeStyle>(), isA<TickerMarqueeStyle>());
  });

  test('slidePanelColor matches primaryContainer', () {
    final t = DisplayTheme.build();
    expect(t.slidePanelColor, t.colorScheme.primaryContainer);
    expect(t.slidePanelOnColor, t.colorScheme.onPrimaryContainer);
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
    expect(graphitePalette.secondaryPairGradient.colors, hasLength(3));
    expect(
      DisplayTheme.buildFromKvValue(kDisplayThemeNavyCoral).brightness,
      Brightness.dark,
    );
    expect(
      DisplayTheme.buildFromKvValue(null).brightness,
      DisplayTheme.build().brightness,
    );
  });

  test('Coolors trending theme builds multi-accent palette', () {
    final ocean = DisplayTheme.buildForId(kDisplayThemeOceanDepth);
    final palette = ocean.extension<PaletteTertiaryLayers>();
    expect(ocean.brightness, Brightness.dark);
    expect(palette, isNotNull);
    expect(palette!.colorOrder, hasLength(9));
    expect(palette.accent1, isNot(equals(palette.accent2)));
    expect(palette.primaryContainerFill.gradientColors.length, greaterThanOrEqualTo(2));
  });

  test('controller preview includes fills and four accents', () {
    for (final id in registeredDisplayThemeIds) {
      final theme = DisplayTheme.buildForId(id);
      final palette = theme.extension<PaletteTertiaryLayers>();
      expect(palette, isNotNull);
      expect(
        palette!.displayBackgroundFill.gradientColors.length,
        greaterThanOrEqualTo(2),
      );
      expect(
        palette.primaryContainerFill.gradientColors.length,
        greaterThanOrEqualTo(2),
      );
      expect(
        palette.secondaryContainerFill.gradientColors.length,
        greaterThanOrEqualTo(2),
      );
      final colors = _controllerPreviewHex(theme, palette);
      expect(colors.length, greaterThanOrEqualTo(6));
    }
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
