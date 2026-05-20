import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/content_category_defaults.dart';

void main() {
  test('kContentCategoryDefaults has unique ids and icon names', () {
    final ids = <String>{};
    for (final def in kContentCategoryDefaults) {
      expect(def.id.trim(), isNotEmpty);
      expect(ids.add(def.id), isTrue, reason: 'duplicate id ${def.id}');
      expect(def.label.trim(), isNotEmpty);
      expect(def.materialIconName?.trim(), isNotEmpty);
    }
    expect(kContentCategoryDefaults.length, greaterThan(10));
  });
}
