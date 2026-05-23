import 'dart:convert';

import 'package:test/test.dart';
import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/display_overlay_calendar_upcoming_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_falling_images_settings.dart';
import 'package:waddle_shared/persistence/display_overlay_photo_slideshow_settings.dart';

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
      final doc = screenConfigJsonDocForType(t);
      expect(jsonDecode(doc.schema), isA<Map<String, dynamic>>());
      expect(jsonDecode(doc.example), isA<Object>());
      expect(
        doc,
        isNot(equals(kGenericScreenConfigJsonDoc)),
        reason: 'Add ScreenConfigJsonDoc for $t',
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
    final hearts = displayOverlayConfigJsonDocForType('shape_rain');
    expect(jsonDecode(hearts.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(hearts.example), isA<Object>());
    final confetti = displayOverlayConfigJsonDocForType('birthday_confetti');
    expect(jsonDecode(confetti.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(confetti.example), isA<Map<String, dynamic>>());
    final bounce = displayOverlayConfigJsonDocForType('bouncing_message');
    expect(jsonDecode(bounce.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(bounce.example), isA<Map<String, dynamic>>());
    final matrix = displayOverlayConfigJsonDocForType('matrix_rain');
    expect(jsonDecode(matrix.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(matrix.example), isA<Map<String, dynamic>>());
    final edgeGlow = displayOverlayConfigJsonDocForType('edge_glow');
    expect(jsonDecode(edgeGlow.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(edgeGlow.example), isA<Map<String, dynamic>>());
    final cloudDrift = displayOverlayConfigJsonDocForType('cloud_drift');
    expect(jsonDecode(cloudDrift.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(cloudDrift.example), isA<Map<String, dynamic>>());
    final balloons = displayOverlayConfigJsonDocForType('floating_balloons');
    expect(jsonDecode(balloons.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(balloons.example), isA<Map<String, dynamic>>());
    final calendarMonth = displayOverlayConfigJsonDocForType('calendar_month');
    expect(jsonDecode(calendarMonth.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(calendarMonth.example), isA<Map<String, dynamic>>());
    final calendarUpcoming = displayOverlayConfigJsonDocForType(
      'calendar_upcoming',
    );
    expect(jsonDecode(calendarUpcoming.schema), isA<Map<String, dynamic>>());
    final stockQuote = displayOverlayConfigJsonDocForType('stock_quote');
    expect(jsonDecode(stockQuote.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(stockQuote.example), isA<Map<String, dynamic>>());
    final qrCode = displayOverlayConfigJsonDocForType('qr_code');
    expect(jsonDecode(qrCode.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(qrCode.example), isA<Map<String, dynamic>>());
    final photoSlideshow = displayOverlayConfigJsonDocForType(
      'photo_slideshow',
    );
    expect(jsonDecode(photoSlideshow.schema), isA<Map<String, dynamic>>());
    expect(jsonDecode(photoSlideshow.example), isA<Map<String, dynamic>>());
    final slideshowSchema =
        jsonDecode(photoSlideshow.schema) as Map<String, dynamic>;
    expect(slideshowSchema['required'], ['interval_sec']);
    final slideshowProps =
        slideshowSchema['properties'] as Map<String, dynamic>;
    final interval = slideshowProps['interval_sec'] as Map<String, dynamic>;
    expect(interval['minimum'], kPhotoSlideshowIntervalSecMin);
    expect(interval['maximum'], kPhotoSlideshowIntervalSecMax);
    final stockQuoteSchema =
        jsonDecode(stockQuote.schema) as Map<String, dynamic>;
    expect(stockQuoteSchema['required'], ['symbolId']);
    final qrCodeSchema = jsonDecode(qrCode.schema) as Map<String, dynamic>;
    expect(qrCodeSchema['required'], ['payload', 'template']);
    final qrProps = qrCodeSchema['properties'] as Map<String, dynamic>;
    final qrTemplate = qrProps['template'] as Map<String, dynamic>;
    expect(qrTemplate['enum'], isNotEmpty);
    final upcomingSchema =
        jsonDecode(calendarUpcoming.schema) as Map<String, dynamic>;
    final upcomingProps = upcomingSchema['properties'] as Map<String, dynamic>;
    final days = upcomingProps['upcomingDays'] as Map<String, dynamic>;
    expect(days['minimum'], kCalendarUpcomingOverlayDaysMin);
    expect(days['maximum'], kCalendarUpcomingOverlayDaysMax);
    final falling = displayOverlayConfigJsonDocForType('falling_images');
    final fallingSchema = jsonDecode(falling.schema) as Map<String, dynamic>;
    final fallingProps = fallingSchema['properties'] as Map<String, dynamic>;
    final dropInterval =
        fallingProps['drop_interval_sec'] as Map<String, dynamic>;
    expect(dropInterval['minimum'], kFallingImagesDropIntervalSecMin);
    final imageScale = fallingProps['image_scale'] as Map<String, dynamic>;
    expect(imageScale['maximum'], kFallingImagesImageScaleMax);
    final fallSpeed = fallingProps['fall_speed'] as Map<String, dynamic>;
    expect(fallSpeed['minimum'], kFallingImagesFallSpeedPxPerSecMin);
    expect(fallSpeed['maximum'], kFallingImagesFallSpeedPxPerSecMax);
  });

  test('weather_openweathermap schema has no baseUrl or defaultLocation', () {
    final doc = kProviderConfigJsonMeta['weather_openweathermap']!;
    final schema = jsonDecode(doc.schema) as Map<String, dynamic>;
    final properties = schema['properties'] as Map<String, dynamic>;
    expect(properties.containsKey('baseUrl'), isFalse);
    expect(properties.containsKey('defaultLocation'), isFalse);
    expect(schema['additionalProperties'], isFalse);
    expect(properties.containsKey('units'), isTrue);
    expect(properties.containsKey('hourlyCount'), isTrue);
    final example = jsonDecode(doc.example) as Map<String, dynamic>;
    expect(example.containsKey('baseUrl'), isFalse);
    expect(example.containsKey('defaultLocation'), isFalse);
  });

  test('seeded provider types have explicit meta entries', () {
    const seededTypes = [
      'stub',
      'news_rss',
      'joke_openai',
      'joke_jokeapi',
      'trivia_openai',
      'trivia_opentdb',
      'weather_openweathermap',
      'weather_alerts_nws',
      'photo_pexels',
      'video_pexels',
      'stock_finnhub',
      'home_assistant',
      'calendar_google',
      'calendar_outlook',
      'photo_onedrive',
      'video_onedrive',
      'photo_flickr',
      'photo_bing_image_of_the_day',
    ];
    for (final t in seededTypes) {
      expect(kProviderConfigJsonMeta.containsKey(t), isTrue);
    }
  });
}
