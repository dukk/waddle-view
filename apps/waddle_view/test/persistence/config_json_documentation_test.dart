import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/persistence/config_json_documentation.dart';

void main() {
  test('provider meta schemas and examples are valid JSON', () {
    for (final entry in kProviderConfigJsonMeta.entries) {
      expect(jsonDecode(entry.value.schema), isA<Map<String, dynamic>>());
      expect(jsonDecode(entry.value.example), isA<Object>());
    }
    final generic = providerConfigJsonDocForType('unknown_provider_xyz');
    expect(jsonDecode(generic.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(generic.example), isA<Object>());
  });

  test('layout schema and example decode', () {
    expect(jsonDecode(kScreenLayoutJsonSchema), isA<Map<String, dynamic>>());
    expect(jsonDecode(kExampleScreenLayoutJson), isA<Map<String, dynamic>>());
  });

  test('seeded provider types have explicit meta entries', () {
    const seededTypes = [
      'stub',
      'rss',
      'jokes',
      'trivia',
      'weather',
      'pexels',
      'outlook_calendar',
    ];
    for (final t in seededTypes) {
      expect(kProviderConfigJsonMeta.containsKey(t), isTrue);
    }
  });
}
