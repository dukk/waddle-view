import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/kv_schema_documentation.dart';

void main() {
  test('every kv widget has config meta and valid expectedValueType', () {
    for (final type in kKvWidgetTypes) {
      final doc = kKvWidgetConfigJsonMeta[type];
      expect(doc, isNotNull, reason: type);
      expect(doc!.schema.trim().isNotEmpty, isTrue);
      expect(doc.example.trim().isNotEmpty, isTrue);
      expect(kKvValueDataTypeMeta.containsKey(doc.expectedValueType), isTrue);
    }
  });

  test('value type examples decode as JSON', () {
    for (final doc in kKvValueDataTypeMeta.values) {
      expect(() => jsonDecode(doc.example), returnsNormally);
      expect(() => jsonDecode(doc.schema), returnsNormally);
    }
  });

  test('general layout slot ids match screen type', () {
    expect(generalLayoutSlotIdsForScreenType('general_2_column').length, 2);
    expect(generalLayoutSlotIdsForScreenType('general_3x2').length, 6);
  });
}
