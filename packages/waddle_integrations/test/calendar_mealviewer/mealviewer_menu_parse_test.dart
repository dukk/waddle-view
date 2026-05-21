import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:waddle_integrations/calendar_mealviewer/mealviewer_menu_parse.dart';

void main() {
  test('parseMealviewerMenuEvents extracts all blocks with items', () {
    final raw = File(
      'test/calendar_mealviewer/fixtures/elmwood_menu_sample.json',
    ).readAsStringSync();
    final root = jsonDecode(raw) as Map<String, dynamic>;
    final events = parseMealviewerMenuEvents(
      root: root,
      schoolLabel: 'Elmwood Elementary',
    );
    expect(events.length, 2);
    expect(events[0].blockName, 'Breakfast');
    expect(events[0].title, contains('Elmwood Elementary'));
    expect(events[0].title, contains('Mini Cinnis'));
    expect(events[0].startUtc, DateTime.utc(2026, 5, 19));
    expect(events[1].blockName, 'Lunch');
    expect(events[1].description, contains('Chicken Patty'));
    expect(events[1].externalId, '2026-05-19:lunch');
    expect(events[0].externalId, '2026-05-19:breakfast');
  });
}
