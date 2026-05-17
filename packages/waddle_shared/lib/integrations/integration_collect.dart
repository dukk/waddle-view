import '../persistence/database.dart';

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

/// Last-collect KV key scoped to one integration row id.
String integrationLastCollectKvKey(String integrationId) =>
    'provider.$integrationId.last_collect_ms';
