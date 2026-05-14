import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/theme/theme_palette_extension.dart';

LinearGradient _g(Color a, Color b) => LinearGradient(colors: [a, b]);

const _c1 = Color(0xFF010101);
const _c2 = Color(0xFF020202);
const _c3 = Color(0xFF030303);
const _c4 = Color(0xFF040404);

PaletteTertiaryLayers _sample({
  Map<Color, List<Color>> tertiary = const {},
}) {
  return PaletteTertiaryLayers(
    primary: const Color(0xFF111111),
    iconColor: const Color(0xFF222222),
    accent1: const Color(0xFF333333),
    accent2: const Color(0xFF444444),
    accent3: const Color(0xFF555555),
    accent4: const Color(0xFF666666),
    colorOrder: const [Color(0xFF666666)],
    tertiaryLayersByColor: tertiary,
    primaryPairGradient: _g(_c1, _c2),
    secondaryPairGradient: _g(_c3, _c4),
  );
}

void main() {
  test('tertiaryLayersFor returns transparents when missing or empty', () {
    final p = _sample();
    expect(
      p.tertiaryLayersFor(const Color(0xFFABCDEF)),
      equals(<Color>[
        Colors.transparent,
        Colors.transparent,
        Colors.transparent,
        Colors.transparent,
      ]),
    );
    final q = _sample(
      tertiary: {const Color(0xFF000011): const <Color>[]},
    );
    expect(
      q.tertiaryLayersFor(const Color(0xFF000011)),
      equals(<Color>[
        Colors.transparent,
        Colors.transparent,
        Colors.transparent,
        Colors.transparent,
      ]),
    );
  });

  test('tertiaryLayersFor returns map entry when present', () {
    final layers = const [Color(0xFF0A0A0A), Color(0xFF0B0B0B)];
    final p = _sample(tertiary: {const Color(0xFF999999): layers});
    expect(
      identical(p.tertiaryLayersFor(const Color(0xFF999999)), layers),
      isTrue,
    );
  });

  test('copyWith replaces only provided fields', () {
    final a = _sample();
    final b = a.copyWith(primary: const Color(0xFFAAAAAA));
    expect(b.primary, const Color(0xFFAAAAAA));
    expect(b.iconColor, a.iconColor);
    final c = a.copyWith();
    expect(c.primary, a.primary);
    expect(c.iconColor, a.iconColor);
  });

  test('lerp returns this for wrong extension type', () {
    final a = _sample();
    expect(identical(a.lerp(null, 0.5), a), isTrue);
  });

  test('lerp blends colors and switches lists past halfway', () {
    final a = _sample(
      tertiary: {
        const Color(0xFF010101): const [Color(0xFF101010)],
      },
    );
    final b = _sample(
      tertiary: {
        const Color(0xFF020202): const [Color(0xFF202020)],
      },
    );
    final mid = a.lerp(b, 0.75);
    expect(mid.colorOrder, b.colorOrder);
    expect(mid.tertiaryLayersByColor, b.tertiaryLayersByColor);
    expect(mid.primaryPairGradient, b.primaryPairGradient);
    expect(mid.secondaryPairGradient, b.secondaryPairGradient);
    final low = a.lerp(b, 0.25);
    expect(low.colorOrder, a.colorOrder);
    expect(low.tertiaryLayersByColor, a.tertiaryLayersByColor);
  });
}
