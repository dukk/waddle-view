import 'package:test/test.dart';
import 'package:waddle_shared/persistence/catalog_id_allocation.dart';

void main() {
  test('allocateScreenIdFromName slugifies and dedupes', () {
    expect(
      allocateScreenIdFromName("Mother's Day", []),
      'mother_s_day',
    );
    expect(
      allocateScreenIdFromName("Mother's Day", ['mother_s_day']),
      'mother_s_day_2',
    );
  });

  test('allocateTickerTapeIdFromName prefixes non-alpha starts', () {
    expect(allocateTickerTapeIdFromName('123 party', []), 't_123_party');
  });

  test('allocateOverlayIdFromName matches overlay slug rules', () {
    expect(allocateOverlayIdFromName('123 party', []), 'o_123_party');
  });
}
