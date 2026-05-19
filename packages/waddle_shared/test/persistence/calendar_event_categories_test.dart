import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/calendar_event_categories.dart';

void main() {
  group('parseCalendarConfigCategoryIds', () {
    test('accepts string and list forms', () {
      expect(parseCalendarConfigCategoryIds('work'), ['work']);
      expect(
        parseCalendarConfigCategoryIds(['work', 'family', 'work']),
        ['work', 'family'],
      );
    });
  });

  group('normalizeCalendarEventCategoryIds', () {
    test('dedupes and trims', () {
      expect(
        normalizeCalendarEventCategoryIds([' work ', '', 'work', 'family']),
        ['work', 'family'],
      );
    });
  });
}
