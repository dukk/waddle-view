import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/theme/config/coolors_palette_expand.dart';
import 'package:waddle_display/theme/config/palettes/coolors_trending_palettes.dart';

void main() {
  test('nineColorTvPaletteFromCoolorsFive builds 9 colors', () {
    final palette = nineColorTvPaletteFromCoolorsFive(const [
      Color(0xFF264653),
      Color(0xFF2A9D8F),
      Color(0xFFE9C46A),
      Color(0xFFF4A261),
      Color(0xFFE76F51),
    ]);
    expect(palette.orderedPalette, hasLength(9));
    expect(palette.accents, hasLength(4));
    expect(palette.background.computeLuminance(), lessThan(0.12));
  });

  test('light Coolors palettes are darkened for TV surfaces', () {
    final palette = CoolorsTrendingPalettes.sageWellness;
    expect(palette.background.computeLuminance(), lessThan(0.12));
    expect(palette.footerBar.computeLuminance(), lessThan(0.12));
    expect(palette.primaryText.computeLuminance(), greaterThan(0.4));
  });

  test('all trending palettes expose tertiary layers for each ordered color', () {
    final palettes = [
      CoolorsTrendingPalettes.tealGoldSunset,
      CoolorsTrendingPalettes.oceanDepth,
      CoolorsTrendingPalettes.forestCream,
      CoolorsTrendingPalettes.heritageCoast,
      CoolorsTrendingPalettes.plumEmber,
      CoolorsTrendingPalettes.slateCrimson,
      CoolorsTrendingPalettes.wineEmber,
      CoolorsTrendingPalettes.dopaminePop,
      CoolorsTrendingPalettes.sageWellness,
      CoolorsTrendingPalettes.warmMinimal,
    ];
    for (final palette in palettes) {
      expect(palette.orderedPalette, hasLength(9));
      expect(palette.accents, hasLength(4));
    }
  });
}
