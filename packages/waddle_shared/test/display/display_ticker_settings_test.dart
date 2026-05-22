import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/display/display_ticker_settings.dart';

void main() {
  test('normalizeDisplayTickerSeparator defaults and explicit values', () {
    expect(
      normalizeDisplayTickerSeparator(
        null,
        defaultValue: kDefaultDisplayTickerItemSeparator,
      ),
      kDisplayTickerSeparatorDot,
    );
    expect(
      normalizeDisplayTickerSeparator(
        'DIAMOND',
        defaultValue: kDefaultDisplayTickerItemSeparator,
      ),
      kDisplayTickerSeparatorDiamond,
    );
    expect(
      normalizeDisplayTickerSeparator(
        'dot',
        defaultValue: kDefaultDisplayTickerProgramSeparator,
      ),
      kDisplayTickerSeparatorDot,
    );
    expect(
      normalizeDisplayTickerSeparator(
        'invalid',
        defaultValue: kDefaultDisplayTickerProgramSeparator,
      ),
      kDefaultDisplayTickerProgramSeparator,
    );
  });

  test('parseDisplayTickerSettingsFromKv uses separator defaults when missing', () {
    final settings = parseDisplayTickerSettingsFromKv({});
    expect(settings.itemSeparator, kDefaultDisplayTickerItemSeparator);
    expect(settings.programSeparator, kDefaultDisplayTickerProgramSeparator);
  });

  test('parseDisplayTickerSettingsFromKv reads separator keys', () {
    final settings = parseDisplayTickerSettingsFromKv({
      kDisplayTickerItemSeparatorKvKey: 'diamond',
      kDisplayTickerProgramSeparatorKvKey: 'dot',
    });
    expect(settings.itemSeparator, kDisplayTickerSeparatorDiamond);
    expect(settings.programSeparator, kDisplayTickerSeparatorDot);
  });
}
