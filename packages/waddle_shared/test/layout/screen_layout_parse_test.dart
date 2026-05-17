import 'dart:convert';

import 'package:test/test.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';

void main() {
  group('defaultSummaryCapacityCharsFor', () {
    test('news reads int or double summaryCapacityChars', () {
      expect(
        defaultSummaryCapacityCharsFor('news', {'summaryCapacityChars': 900}),
        900,
      );
      expect(
        defaultSummaryCapacityCharsFor('news', {'summaryCapacityChars': 12.7}),
        13,
      );
      expect(
        defaultSummaryCapacityCharsFor('news', <String, dynamic>{}),
        1200,
      );
    });

    test('news_columns uses per-column key', () {
      expect(
        defaultSummaryCapacityCharsFor(
          'news_columns',
          {'summaryCapacityCharsPerColumn': 100},
        ),
        100,
      );
      expect(
        defaultSummaryCapacityCharsFor('news_columns', {}),
        220,
      );
    });

    test('news_stack uses per-slot key', () {
      expect(
        defaultSummaryCapacityCharsFor(
          'news_stack',
          {'summaryCapacityCharsPerSlot': 400},
        ),
        400,
      );
      expect(
        defaultSummaryCapacityCharsFor('news_stack', {}),
        320,
      );
    });

    test('non-rss types return 0', () {
      expect(defaultSummaryCapacityCharsFor('static_text', {}), 0);
    });
  });

  group('computeRssSummarySlotCapacities', () {
    test('news returns one slot', () {
      expect(
        computeRssSummarySlotCapacities('news', {'summaryCapacityChars': 500}),
        [500],
      );
    });

    test('news_columns repeats per columnCount clamped 1–6', () {
      expect(
        computeRssSummarySlotCapacities(
          'news_columns',
          {'columnCount': 1, 'summaryCapacityCharsPerColumn': 50},
        ),
        [50],
      );
      expect(
        computeRssSummarySlotCapacities(
          'news_columns',
          {'columnCount': 10, 'summaryCapacityCharsPerColumn': 40},
        ),
        List<int>.filled(6, 40),
      );
      expect(
        computeRssSummarySlotCapacities(
          'news_columns',
          {'columnCount': 3.2, 'summaryCapacityCharsPerColumn': 30},
        ),
        List<int>.filled(3, 30),
      );
      expect(
        computeRssSummarySlotCapacities('news_columns', {}),
        List<int>.filled(3, 220),
      );
    });

    test('news_stack always uses two slots', () {
      expect(
        computeRssSummarySlotCapacities('news_stack', {'summaryCapacityCharsPerSlot': 111}),
        [111, 111],
      );
    });

    test('other types return empty', () {
      expect(computeRssSummarySlotCapacities('weather', {}), isEmpty);
    });
  });

  group('parseScreenLayoutWidgets', () {
    test('invalid JSON yields empty list', () {
      expect(parseScreenLayoutWidgets('{'), isEmpty);
    });

    test('non-object root yields empty list', () {
      expect(parseScreenLayoutWidgets('[]'), isEmpty);
    });

    test('missing or non-list widgets yields empty list', () {
      expect(parseScreenLayoutWidgets('{}'), isEmpty);
      expect(parseScreenLayoutWidgets('{"widgets":{}}'), isEmpty);
    });

    test('parses valid widgets and skips malformed entries', () {
      final json = jsonEncode({
        'widgets': [
          {'type': 'clock', 'slot': 'main', 'config': {'tz': 'UTC'}},
          {'type': 1, 'slot': 'x'},
          {'type': 'news', 'slot': 'side', 'config': {'summaryCapacityChars': 100}},
        ],
      });
      final specs = parseScreenLayoutWidgets(json);
      expect(specs.length, 2);
      expect(specs[0].type, 'clock');
      expect(specs[0].slot, 'main');
      expect(specs[0].config, {'tz': 'UTC'});
      expect(specs[0].rssSummarySlotCapacities, isEmpty);
      expect(specs[0].choiceKey, 'main_clock');

      expect(specs[1].type, 'news');
      expect(specs[1].rssSummarySlotCapacities, [100]);
    });

    test('non-map config becomes empty map', () {
      final json = jsonEncode({
        'widgets': [
          {'type': 'static_text', 'slot': 'a', 'config': 'broken'},
        ],
      });
      final specs = parseScreenLayoutWidgets(json);
      expect(specs.single.config, isEmpty);
    });
  });

  group('extractLegacyScreenFields', () {
    test('empty layout defaults to static_text', () {
      final r = extractLegacyScreenFields('{}');
      expect(r.screenType, 'static_text');
      expect(r.configJson, '{}');
    });

    test('first widget wins', () {
      final json = jsonEncode({
        'widgets': [
          {'type': 'joke', 'slot': 'main', 'config': {'x': 1}},
          {'type': 'weather', 'slot': 'side', 'config': {'y': 2}},
        ],
      });
      final r = extractLegacyScreenFields(json);
      expect(r.screenType, 'joke');
      expect(jsonDecode(r.configJson), {'x': 1});
    });
  });

  group('synthesizeLayoutJson', () {
    test('roundtrips object config', () {
      const screenType = 'news';
      const cfg = '{"feedId":"f1"}';
      final layout = synthesizeLayoutJson(screenType: screenType, configJson: cfg);
      final specs = parseScreenLayoutWidgets(layout);
      expect(specs.single.type, screenType);
      expect(specs.single.config, {'feedId': 'f1'});
    });

    test('malformed configJson becomes empty object', () {
      final layout = synthesizeLayoutJson(
        screenType: 'static_text',
        configJson: 'not-json',
      );
      final specs = parseScreenLayoutWidgets(layout);
      expect(specs.single.config, isEmpty);
    });

    test('non-map decoded config becomes empty object', () {
      final layout = synthesizeLayoutJson(
        screenType: 'static_text',
        configJson: '"string"',
      );
      final specs = parseScreenLayoutWidgets(layout);
      expect(specs.single.config, isEmpty);
    });

    test('custom slot is preserved', () {
      final layout = synthesizeLayoutJson(
        screenType: 'clock',
        configJson: '{}',
        slot: 'hero',
      );
      final specs = parseScreenLayoutWidgets(layout);
      expect(specs.single.slot, 'hero');
    });
  });
}
