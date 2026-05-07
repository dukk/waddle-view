import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/content_category_material_icon.dart';
import 'package:waddle_display/persistence/content_category_defaults.dart';

void main() {
  test('every default materialIconName resolves to a non-fallback icon', () {
    for (final d in kContentCategoryDefaults) {
      final name = d.materialIconName;
      expect(name, isNotNull);
      final icon = contentCategoryMaterialIcon(name);
      expect(icon, isNot(equals(Icons.label_outline)));
    }
  });

  test('null and unknown names use fallback', () {
    expect(contentCategoryMaterialIcon(null), Icons.label_outline);
    expect(contentCategoryMaterialIcon('no_such_icon'), Icons.label_outline);
  });
}
