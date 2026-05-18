import '../persistence/database.dart';

export 'integration_kv_types.dart' show kIntegrationLastCollectKey;

/// Enabled [Integrations] rows for one [integrationType].
Future<List<Integration>> enabledIntegrationsForType(
  AppDatabase db,
  String integrationType,
) async {
  final type = integrationType.trim();
  final rows = await (db.select(db.integrations)
        ..where((t) => t.integrationType.equals(type)))
      .get();
  return rows.where((r) => r.enabled).toList(growable: false);
}

/// @deprecated Use [kIntegrationLastCollectKey] with [IntegrationKvRepository].
@Deprecated('Use kIntegrationLastCollectKey with IntegrationKvRepository')
String integrationLastCollectKvKey(String integrationId) =>
    'provider.$integrationId.last_collect_ms';
