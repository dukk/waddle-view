import 'dart:convert';

import 'package:test/test.dart';
import 'package:waddle_shared/persistence/config_json_documentation.dart';

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

  test('every screen layout widget type has config schema entry', () {
    for (final t in kScreenLayoutWidgetTypes) {
      expect(
        kScreenConfigJsonMeta.containsKey(t),
        isTrue,
        reason: 'Add ScreenConfigJsonDoc for $t in kScreenConfigJsonMeta',
      );
    }
  });

  test('ticker slot meta schemas decode and cover all ticker types', () {
    for (final entry in kTickerSlotConfigJsonMeta.entries) {
      expect(jsonDecode(entry.value.schema), isA<Map<String, dynamic>>());
      expect(jsonDecode(entry.value.example), isA<Object>());
    }
    for (final t in kTickerSlotDefinitionTypes) {
      expect(
        kTickerSlotConfigJsonMeta.containsKey(t),
        isTrue,
        reason: 'Add ScreenConfigJsonDoc for ticker type $t',
      );
    }
    final generic = tickerSlotConfigJsonDocForType('unknown_ticker_xyz');
    expect(jsonDecode(generic.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(generic.example), isA<Object>());
  });

  test('display overlay schedule config meta decodes', () {
    final hearts = displayOverlayConfigJsonDocForType('hearts_rain');
    expect(jsonDecode(hearts.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(hearts.example), isA<Object>());
    final confetti = displayOverlayConfigJsonDocForType('birthday_confetti');
    expect(jsonDecode(confetti.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(confetti.example), isA<Map<String, dynamic>>());
    final bounce = displayOverlayConfigJsonDocForType('bouncing_message');
    expect(jsonDecode(bounce.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(bounce.example), isA<Map<String, dynamic>>());
  });

  test('seeded provider types have explicit meta entries', () {
    const seededTypes = [
      'stub',
      'news_rss',
      'joke_openai',
      'trivia_openai',
      'trivia_opentdb',
      'weather_openweathermap',
      'weather_nws_alerts',
      'media_pexels',
      'stock_finnhub',
      'calendar_google',
      'calendar_outlook',
      'media_onedrive',
      'media_flickr',
      'media_bing_iotd',
    ];
    for (final t in seededTypes) {
      expect(kProviderConfigJsonMeta.containsKey(t), isTrue);
    }
  });
}
