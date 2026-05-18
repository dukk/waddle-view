import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/theme/display_theme.dart';

void main() {
  test('semantics resolve navy_coral container roles', () {
    final theme = DisplayTheme.build();
    expect(
      theme.displayBackgroundFill.gradientColors,
      NavyCoralPalette.displayBackgroundFill.gradientColors,
    );
    expect(
      theme.slideChromeFill.gradientColors,
      NavyCoralPalette.primaryContainerFill.gradientColors,
    );
    expect(
      theme.tickerChromeFill.gradientColors,
      NavyCoralPalette.secondaryContainerFill.gradientColors,
    );
    expect(theme.accent(1), NavyCoralPalette.accents[0]);
    expect(theme.progressIndicatorColor, NavyCoralPalette.accents[0]);
  });

  test('semantics resolve Coolors-derived ocean_depth', () {
    final theme = DisplayTheme.buildForId(kDisplayThemeOceanDepth);
    expect(theme.slidePanelColor, theme.colorScheme.primaryContainer);
    expect(theme.accent(2), isNot(equals(theme.accent(1))));
    expect(theme.slideChromeFill.hasGradient, isTrue);
  });
}
