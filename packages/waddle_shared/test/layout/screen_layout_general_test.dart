import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';

void main() {
  test('synthesizeLayoutJson expands general_2_column slots', () {
    const config = '''
{
  "slots": [
    {
      "slot": "left",
      "widget": {
        "type": "kv_list",
        "config": {
          "integrationId": "default_general_openai",
          "valueKey": "prompt.daily_summary.latest"
        }
      }
    },
    {
      "slot": "right",
      "widget": {
        "type": "kv_gauge",
        "config": {
          "integrationId": "default_general_openai",
          "valueKey": "prompt.score.latest"
        }
      }
    }
  ]
}
''';
    final layout = synthesizeLayoutJson(
      screenType: 'general_2_column',
      configJson: config,
    );
    final decoded = jsonDecode(layout) as Map<String, dynamic>;
    expect(decoded['layout'], 'general_2_column');
    final widgets = decoded['widgets'] as List;
    expect(widgets.length, 2);
    expect(widgets.first['type'], 'kv_list');
    expect(widgets.first['slot'], 'left');
  });
}
