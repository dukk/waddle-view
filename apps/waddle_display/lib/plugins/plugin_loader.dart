import 'dart:io';

import 'package:drift/drift.dart';
import 'package:waddle_shared/extensions/data_provider_registry.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/plugins/plugin_manifest.dart';

/// Discovers drop-in plugins under [rootDir] and registers HTTP collectors.
class PluginLoader {
  PluginLoader({
    required this.db,
    required this.providerRegistry,
  });

  final AppDatabase db;
  final DataProviderRegistry providerRegistry;

  final List<LoadedPlugin> loaded = [];

  Future<void> scanDirectory(String rootDir) async {
    loaded.clear();
    final dir = Directory(rootDir);
    if (!await dir.exists()) {
      return;
    }
    await for (final entity in dir.list()) {
      if (entity is! Directory) {
        continue;
      }
      try {
        final manifest = await PluginManifest.loadDirectory(entity.path);
        final plugin = LoadedPlugin(manifest: manifest, path: entity.path);
        loaded.add(plugin);
        await _persistInstall(plugin);
        await _ensureIntegrationRows(manifest);
      } on Object {
        // skip invalid plugin folders
      }
    }
  }

  Future<void> _persistInstall(LoadedPlugin plugin) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final manifestFile = File('${plugin.path}/manifest.json');
    final raw = await manifestFile.readAsString();
    await db.into(db.installedPlugins).insertOnConflictUpdate(
          InstalledPluginsCompanion.insert(
            id: plugin.manifest.id,
            version: plugin.manifest.version,
            manifestJson: raw,
            installPath: plugin.path,
            enabled: const Value(true),
            installedAtMs: nowMs,
          ),
        );
  }

  Future<void> _ensureIntegrationRows(PluginManifest manifest) async {
    for (final i in manifest.integrations) {
      if (i.id.isEmpty) {
        continue;
      }
      final existing = await (db.select(db.integrations)
            ..where((t) => t.id.equals(i.id)))
          .getSingleOrNull();
      if (existing != null) {
        continue;
      }
      await db.into(db.integrations).insert(
            IntegrationsCompanion.insert(
              id: i.id,
              providerType: i.providerType,
              enabled: const Value(false),
              pollSeconds: const Value(60),
              configJson: const Value('{"collect_url":""}'),
            ),
          );
    }
  }
}

class LoadedPlugin {
  const LoadedPlugin({required this.manifest, required this.path});

  final PluginManifest manifest;
  final String path;
}
