import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/extensions/data_provider_registry.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

/// Generic HTTP collector for `plugin_http` integrations (sidecar `/collect`).
class PluginHttpDataProvider implements IDataProvider {
  PluginHttpDataProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get id => kPluginHttpCollectorId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final rows = await ctx.db.select(ctx.db.integrations).get();
    for (final row in rows) {
      if (!row.enabled) {
        continue;
      }
      if (row.providerType.trim() != kProviderTypePluginHttp) {
        continue;
      }
      final config = _parseConfig(row.configJson);
      final collectUrl = (config['collect_url'] as String?)?.trim();
      if (collectUrl == null || collectUrl.isEmpty) {
        continue;
      }
      await _collectOne(ctx, integrationId: row.id, collectUrl: collectUrl, config: config);
    }
  }

  Future<void> _collectOne(
    DataWriteContext ctx, {
    required String integrationId,
    required String collectUrl,
    required Map<String, dynamic> config,
  }) async {
    try {
      final headers = <String, String>{'Accept': 'application/json'};
      final hdr = config['headers'];
      if (hdr is Map) {
        for (final e in hdr.entries) {
          headers[e.key.toString()] = e.value.toString();
        }
      }
      final res = await _client
          .post(Uri.parse(collectUrl), headers: headers)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return;
      }
      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) {
        return;
      }
      final kvPatches = body['config_kv_patches'];
      if (kvPatches is Map) {
        for (final e in kvPatches.entries) {
          final key = e.key.toString().trim();
          if (key.isEmpty) {
            continue;
          }
          await ctx.db.into(ctx.db.configKeyValues).insertOnConflictUpdate(
                ConfigKeyValuesCompanion.insert(
                  key: key,
                  value: e.value.toString(),
                ),
              );
        }
      }
      ctx.diagnostics.provider('plugin_http $integrationId: collect ok');
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('plugin_http $integrationId', e, st);
    }
  }

  Map<String, dynamic> _parseConfig(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const {};
    }
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) {
        return v;
      }
    } on Object {
      // ignore
    }
    return const {};
  }
}
