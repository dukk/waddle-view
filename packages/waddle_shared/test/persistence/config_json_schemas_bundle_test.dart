import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/config_json_schemas_bundle.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/seed/tables/integration_types_seed.dart';

import '../helpers/memory_database.dart';

void main() {
  test('decodeConfigJsonDocField handles null empty and invalid json', () {
    expect(decodeConfigJsonDocField(null), isNull);
    expect(decodeConfigJsonDocField(''), isNull);
    expect(decodeConfigJsonDocField('not-json'), 'not-json');
    expect(decodeConfigJsonDocField('{"a":1}'), {'a': 1});
  });

  test('screenTypeConfigJsonMetaItemFromRow uses row schema override', () {
    final item = screenTypeConfigJsonMetaItemFromRow(
      ScreenType(
        screenType: 'weather',
        label: 'Weather label',
        configJsonSchema: '{"type":"object","title":"custom"}',
      ),
    );
    expect(item['screen_type'], 'weather');
    expect(item['label'], 'Weather label');
    expect(item['config_json_schema'], isA<Map>());
    expect(item['example_config_json'], isA<Map>());
  });

  test('buildIntegrationTypeConfigJsonMetaItemsFromDb reads seeded types', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    await ensureIntegrationTypes(db);
    final items = await buildIntegrationTypeConfigJsonMetaItemsFromDb(db);
    expect(items, isNotEmpty);
    expect(
      items.any((e) => e['integration_type'] == 'photo_pexels'),
      isTrue,
    );
  });

  test('sortOverlayTypeConfigJsonMetaItems orders effect before widget', () {
    final items = [
      {
        'overlay_type': 'z_widget',
        'label': 'Z',
        'category': 'widget',
      },
      {
        'overlay_type': 'a_effect',
        'label': 'A',
        'category': 'effect',
      },
    ];
    sortOverlayTypeConfigJsonMetaItems(items);
    expect(items.first['category'], 'effect');
    expect(items.last['category'], 'widget');
  });

  test('buildConfigJsonSchemasBundle has non-empty typed sections', () {
    final bundle = buildConfigJsonSchemasBundle();
    for (final key in [
      'screen_types',
      'ticker_tape_types',
      'overlay_types',
      'integration_types',
      'kv_widget_types',
      'kv_value_data_types',
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

  test('overlay type items include category and requires_placement', () {
    final items = buildOverlayTypeConfigJsonMetaItems();
    expect(items, isNotEmpty);
    for (final raw in items) {
      final item = raw;
      expect(item['overlay_type'], isA<String>());
      expect(item['category'], isIn(['effect', 'widget']));
      expect(item['requires_placement'], isA<bool>());
      final category = item['category'] as String;
      final requiresPlacement = item['requires_placement'] as bool;
      if (category == 'widget') {
        expect(requiresPlacement, isTrue);
      } else {
        expect(requiresPlacement, isFalse);
      }
    }
    final widget = items.firstWhere(
      (e) => e['overlay_type'] == kOverlayTypeDigitalClock,
    );
    expect(widget['category'], 'widget');
    expect(widget['requires_placement'], isTrue);
    final effect = items.firstWhere(
      (e) => e['overlay_type'] == kOverlayTypeShapeRain,
    );
    expect(effect['category'], 'effect');
    expect(effect['requires_placement'], isFalse);
  });

  test('screen type items cover kScreenLayoutWidgetTypes', () {
    final items = buildScreenTypeConfigJsonMetaItems();
    final types = items.map((e) => e['screen_type']).toSet();
    expect(types.length, items.length);
    expect(types.contains('weather'), isTrue);
  });

  test('buildConfigJsonSchemasBundleFromDb aggregates all sections', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    await ensureIntegrationTypes(db);

    final bundle = await buildConfigJsonSchemasBundleFromDb(db);
    for (final key in [
      'screen_types',
      'ticker_tape_types',
      'overlay_types',
      'integration_types',
      'kv_widget_types',
      'kv_value_data_types',
    ]) {
      expect((bundle[key] as List).isNotEmpty, isTrue);
    }
  });

  test('partial overlay_types DB syncs builtins before meta read', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    addTearDown(db.close);

    await db.into(db.overlayTypes).insert(
          OverlayTypesCompanion.insert(
            overlayType: kOverlayTypeShapeRain,
            label: 'Shape rain',
          ),
        );

    final items = await buildOverlayTypeConfigJsonMetaItemsFromDb(db);
    final types = items.map((e) => e['overlay_type'] as String).toSet();
    expect(
      types,
      containsAll([
        kOverlayTypeStaticImage,
        kOverlayTypeDigitalClock,
        kOverlayTypeAnalogClock,
      ]),
    );
    expect(types.length, greaterThanOrEqualTo(kBuiltinOverlayTypes.length));
  });
}
