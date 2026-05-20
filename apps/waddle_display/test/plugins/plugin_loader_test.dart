import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/plugins/plugin_loader.dart';
import 'package:waddle_shared/extensions/data_provider_registry.dart';

import '../helpers/memory_database.dart';

void main() {
  test('scanDirectory loads valid manifest and skips invalid folder', () async {
    final root = await Directory.systemTemp.createTemp('waddle_plugin_test_');
    addTearDown(() => root.delete(recursive: true));

    final valid = Directory('${root.path}/good_plugin');
    await valid.create();
    await File('${valid.path}/manifest.json').writeAsString(
      jsonEncode({
        'id': 'good_plugin',
        'version': '1.0.0',
        'capabilities': ['collect'],
        'integrations': [
          {
            'id': 'good_plugin_collect',
            'integration_type': 'plugin_http',
          },
        ],
      }),
    );

    final invalid = Directory('${root.path}/bad_plugin');
    await invalid.create();
    await File('${invalid.path}/manifest.json').writeAsString('not json');

    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);

    final loader = PluginLoader(
      db: db,
      providerRegistry: DataProviderRegistry(),
    );
    await loader.scanDirectory(root.path);

    expect(loader.loaded, hasLength(1));
    expect(loader.loaded.single.manifest.id, 'good_plugin');

    final installed = await (db.select(db.installedPlugins)
          ..where((t) => t.id.equals('good_plugin')))
        .getSingleOrNull();
    expect(installed, isNotNull);

    final integration = await (db.select(db.integrations)
          ..where((t) => t.id.equals('good_plugin_collect')))
        .getSingleOrNull();
    expect(integration?.integrationType, 'plugin_http');
  });

  test('scanDirectory no-ops when root missing', () async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);

    final loader = PluginLoader(
      db: db,
      providerRegistry: DataProviderRegistry(),
    );
    await loader.scanDirectory(
      '${Directory.systemTemp.path}/waddle_missing_plugins_${DateTime.now().microsecondsSinceEpoch}',
    );
    expect(loader.loaded, isEmpty);
  });
}
