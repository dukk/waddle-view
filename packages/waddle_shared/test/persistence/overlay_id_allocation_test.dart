import 'package:test/test.dart';
import 'package:waddle_shared/persistence/overlay_id_allocation.dart';

void main() {
  test('allocateOverlayIdFromName slugifies and dedupes', () {
    expect(
      allocateOverlayIdFromName("Mother's Day", []),
      'mother_s_day',
    );
    expect(
      allocateOverlayIdFromName("Mother's Day", ['mother_s_day']),
      'mother_s_day_2',
    );
  });

  test('slugifyOverlayName prefixes non-alpha starts', () {
    expect(slugifyOverlayName('123 party'), 'o_123_party');
  });
}
