import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/theme/display_text_scale_kv.dart';

void main() {
  test('normalizeDisplayTextScaleOption defaults and aliases', () {
    expect(normalizeDisplayTextScaleOption(null), kDisplayTextScaleNormal);
    expect(normalizeDisplayTextScaleOption(''), kDisplayTextScaleNormal);
    expect(normalizeDisplayTextScaleOption('  NORMAL  '), kDisplayTextScaleNormal);
    expect(normalizeDisplayTextScaleOption('X-Large'), kDisplayTextScaleXLarge);
    expect(normalizeDisplayTextScaleOption('x_large'), kDisplayTextScaleXLarge);
    expect(normalizeDisplayTextScaleOption('XX Large'), kDisplayTextScaleXXLarge);
    expect(
      normalizeDisplayTextScaleOption('xxx_large'),
      kDisplayTextScaleXXXLarge,
    );
    expect(normalizeDisplayTextScaleOption('smaller'), kDisplayTextScaleSmaller);
  });

  test('unknown option falls back to normal', () {
    expect(normalizeDisplayTextScaleOption('huge'), kDisplayTextScaleNormal);
  });

  test('linearFactorForDisplayTextScaleOption increases then decreases', () {
    expect(
      linearFactorForDisplayTextScaleOption(kDisplayTextScaleXXXSmall),
      lessThan(linearFactorForDisplayTextScaleOption(kDisplayTextScaleXXSmall)),
    );
    expect(
      linearFactorForDisplayTextScaleOption(kDisplayTextScaleXXSmall),
      lessThan(linearFactorForDisplayTextScaleOption(kDisplayTextScaleXSmall)),
    );
    expect(
      linearFactorForDisplayTextScaleOption(kDisplayTextScaleXSmall),
      lessThan(linearFactorForDisplayTextScaleOption(kDisplayTextScaleSmall)),
    );
    expect(
      linearFactorForDisplayTextScaleOption(kDisplayTextScaleSmall),
      lessThan(linearFactorForDisplayTextScaleOption(kDisplayTextScaleNormal)),
    );
    expect(
      linearFactorForDisplayTextScaleOption(kDisplayTextScaleNormal),
      lessThan(linearFactorForDisplayTextScaleOption(kDisplayTextScaleLarge)),
       );
    expect(
      linearFactorForDisplayTextScaleOption(kDisplayTextScaleLarge),
      lessThan(linearFactorForDisplayTextScaleOption(kDisplayTextScaleXLarge)),
    );
    expect(
      linearFactorForDisplayTextScaleOption(kDisplayTextScaleXLarge),
      lessThan(linearFactorForDisplayTextScaleOption(kDisplayTextScaleXXLarge)),
    );
    expect(
      linearFactorForDisplayTextScaleOption(kDisplayTextScaleXXLarge),
      lessThan(linearFactorForDisplayTextScaleOption(kDisplayTextScaleXXXLarge)),
    );
    expect(linearFactorForDisplayTextScaleOption(kDisplayTextScaleNormal), 1.0);
  });

  test('linearFactorForDisplayTextScaleKvValue uses normalization', () {
    expect(
      linearFactorForDisplayTextScaleKvValue('  LARGE '),
      closeTo(1.15, 1e-9),
    );
  });
}
