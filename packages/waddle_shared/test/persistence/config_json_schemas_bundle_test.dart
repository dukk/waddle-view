import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/config_json_schemas_bundle.dart';

void main() {
  test('buildConfigJsonSchemasBundle has non-empty typed sections', () {
    final bundle = buildConfigJsonSchemasBundle();
    for (final key in [
      'screen_types',
      'ticker_tape_types',
      'overlay_types',
      'integration_types',
    ]) {
      final items = bundle[key];
      expect(items, isA<List>());
      expect((items! as List).isNotEmpty, isTrue);
    }
  });

  test('each meta item includes decoded schema and example objects', () {
    final bundle = buildConfigJsonSchemasBundle();
    final screen = (bundle['screen_types']! as List).first as Map;
    expect(screen['screen_type'], isA<String>());
    expect(screen['label'], isA<String>());
    expect(screen['config_json_schema'], isA<Map>());
    expect(screen['example_config_json'], isA<Map>());

    final integration =
        (bundle['integration_types']! as List).first as Map;
    expect(integration['integration_type'], isA<String>());
    expect(integration['label'], isA<String>());
    expect(integration['requires_accounts'], isA<bool>());
    expect(integration['config_json_schema'], isA<Map>());
    expect(integration['example_config_json'], isA<Map>());
  });

  test('screen type items cover kScreenLayoutWidgetTypes', () {
    final items = buildScreenTypeConfigJsonMetaItems();
    final types = items.map((e) => e['screen_type']).toSet();
    expect(types.length, items.length);
    expect(types.contains('weather'), isTrue);
  });
}
