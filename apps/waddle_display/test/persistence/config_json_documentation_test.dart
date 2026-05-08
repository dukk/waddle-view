import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/persistence/config_json_documentation.dart';

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

  test('screen config meta schemas and examples decode', () {
    for (final entry in kScreenConfigJsonMeta.entries) {
      expect(jsonDecode(entry.value.schema), isA<Map<String, dynamic>>());
      expect(jsonDecode(entry.value.example), isA<Object>());
    }
    final generic = screenConfigJsonDocForType('unknown_screen_xyz');
    expect(jsonDecode(generic.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(generic.example), isA<Object>());
    expect(
      jsonDecode(kMigration20ScreenLayoutJsonSchema),
      isA<Map<String, dynamic>>(),
    );
    expect(
      jsonDecode(kMigration20ExampleScreenLayoutJson),
      isA<Map<String, dynamic>>(),
    );
  });

  test('seeded provider types have explicit meta entries', () {
    const seededTypes = [
      'stub',
      'rss',
      'jokes',
      'trivia',
      'opentdb_trivia',
      'weather',
      'nws_weather_alerts',
      'pexels',
      'stocks',
      'google_calendar',
      'outlook_calendar',
      'onedrive_media',
      'flickr_media',
      'bing_iotd',
    ];
    for (final t in seededTypes) {
      expect(kProviderConfigJsonMeta.containsKey(t), isTrue);
    }
  });
}
