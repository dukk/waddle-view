import 'package:drift/drift.dart';

import '../persistence/database.dart';
import 'integration_kv_types.dart';

/// Reads and writes [IntegrationsKeyValue] rows (integration- or account-scoped).
class IntegrationKvRepository {
  const IntegrationKvRepository(this.db);

  final AppDatabase db;

  Future<String?> getIntegrationValue(String integrationId, String key) async {
    final id = integrationId.trim();
    final k = key.trim();
    if (id.isEmpty || k.isEmpty) {
      return null;
    }
    final row = await (db.select(db.integrationsKeyValue)
          ..where((t) => t.integrationId.equals(id) & t.key.equals(k)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<String?> getAccountValue(String accountId, String key) async {
    final id = accountId.trim();
    final k = key.trim();
    if (id.isEmpty || k.isEmpty) {
      return null;
    }
    final row = await (db.select(db.integrationsKeyValue)
          ..where((t) => t.accountId.equals(id) & t.key.equals(k)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> upsertIntegration({
    required String integrationId,
    required String key,
    required String value,
    String? valueType,
  }) async {
    final iid = integrationId.trim();
    final k = key.trim();
    if (iid.isEmpty || k.isEmpty) {
      throw ArgumentError('integrationId and key must be non-empty');
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final existing = await (db.select(db.integrationsKeyValue)
          ..where((t) => t.integrationId.equals(iid) & t.key.equals(k)))
        .getSingleOrNull();
    if (existing != null) {
      await (db.update(db.integrationsKeyValue)
            ..where((t) => t.id.equals(existing.id)))
          .write(
        IntegrationsKeyValueCompanion(
          value: Value(value),
          valueType: Value(valueType),
          updatedAtMs: Value(nowMs),
        ),
      );
      return;
    }
    await db.into(db.integrationsKeyValue).insert(
          IntegrationsKeyValueCompanion.insert(
            integrationId: Value(iid),
            key: k,
            value: value,
            valueType: Value(valueType),
            createdAtMs: nowMs,
            updatedAtMs: nowMs,
          ),
        );
  }

  Future<void> upsertAccount({
    required String accountId,
    required String key,
    required String value,
    String? valueType,
  }) async {
    final aid = accountId.trim();
    final k = key.trim();
    if (aid.isEmpty || k.isEmpty) {
      throw ArgumentError('accountId and key must be non-empty');
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final existing = await (db.select(db.integrationsKeyValue)
          ..where((t) => t.accountId.equals(aid) & t.key.equals(k)))
        .getSingleOrNull();
    if (existing != null) {
      await (db.update(db.integrationsKeyValue)
            ..where((t) => t.id.equals(existing.id)))
          .write(
        IntegrationsKeyValueCompanion(
          value: Value(value),
          valueType: Value(valueType),
          updatedAtMs: Value(nowMs),
        ),
      );
      return;
    }
    await db.into(db.integrationsKeyValue).insert(
          IntegrationsKeyValueCompanion.insert(
            accountId: Value(aid),
            key: k,
            value: value,
            valueType: Value(valueType),
            createdAtMs: nowMs,
            updatedAtMs: nowMs,
          ),
        );
  }

  Future<void> deleteAccountKey(String accountId, String key) async {
    final aid = accountId.trim();
    final k = key.trim();
    if (aid.isEmpty || k.isEmpty) {
      return;
    }
    await (db.delete(db.integrationsKeyValue)
          ..where((t) => t.accountId.equals(aid) & t.key.equals(k)))
        .go();
  }

  Future<void> deleteIntegrationKey(String integrationId, String key) async {
    final iid = integrationId.trim();
    final k = key.trim();
    if (iid.isEmpty || k.isEmpty) {
      return;
    }
    await (db.delete(db.integrationsKeyValue)
          ..where((t) => t.integrationId.equals(iid) & t.key.equals(k)))
        .go();
  }
}

/// Default value type for poll-gate and OAuth expiry keys.
String integrationKvTypeForKey(String key) {
  switch (key) {
    case kIntegrationLastCollectKey:
    case kIntegrationAccessTokenExpiresAtKey:
    case kIntegrationLastDevicePromptKey:
      return kIntegrationKvTypeIntMs;
    default:
      if (key.startsWith(kIntegrationDeltaLinkKeyPrefix)) {
        return kIntegrationKvTypeDeltaLink;
      }
      return kIntegrationKvTypeString;
  }
}
