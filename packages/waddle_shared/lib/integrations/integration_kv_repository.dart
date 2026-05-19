import 'package:drift/drift.dart';

import '../persistence/database.dart';
import 'general_openai_kv_keys.dart';
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

  /// All integration-scoped KV rows, optionally filtered by [keyPrefix].
  Future<List<IntegrationsKeyValueData>> listIntegrationKeys(
    String integrationId, {
    String? keyPrefix,
  }) async {
    final iid = integrationId.trim();
    if (iid.isEmpty) {
      return const [];
    }
    final query = db.select(db.integrationsKeyValue)
      ..where((t) => t.integrationId.equals(iid));
    final prefix = keyPrefix?.trim() ?? '';
    final rows = await query.get();
    if (prefix.isEmpty) {
      return rows;
    }
    return rows.where((r) => r.key.startsWith(prefix)).toList(growable: false);
  }

  /// Inserts a new row (never updates). Used for immutable history keys.
  Future<void> insertIntegration({
    required String integrationId,
    required String key,
    required String value,
    String? valueType,
    int? createdAtMs,
  }) async {
    final iid = integrationId.trim();
    final k = key.trim();
    if (iid.isEmpty || k.isEmpty) {
      throw ArgumentError('integrationId and key must be non-empty');
    }
    final nowMs = createdAtMs ?? DateTime.now().millisecondsSinceEpoch;
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

  /// Deletes rows matching [predicate]. Returns rows removed.
  Future<int> deleteIntegrationKeysWhere(
    String integrationId,
    bool Function(IntegrationsKeyValueData row) predicate,
  ) async {
    final iid = integrationId.trim();
    if (iid.isEmpty) {
      return 0;
    }
    final rows = await listIntegrationKeys(iid);
    var removed = 0;
    for (final row in rows) {
      if (!predicate(row)) {
        continue;
      }
      await (db.delete(db.integrationsKeyValue)
            ..where((t) => t.id.equals(row.id)))
          .go();
      removed++;
    }
    return removed;
  }

  /// Purges history keys under [historyKeyPrefix] older than [cutoffCreatedAtMs],
  /// then enforces [maxEntries] newest rows (by [IntegrationsKeyValueData.createdAtMs]).
  Future<int> purgeIntegrationHistoryKeys({
    required String integrationId,
    required String historyKeyPrefix,
    required int cutoffCreatedAtMs,
    int? maxEntries,
  }) async {
    final prefix = historyKeyPrefix.trim();
    if (prefix.isEmpty) {
      return 0;
    }
    final rows = await listIntegrationKeys(integrationId, keyPrefix: prefix);
    var removed = 0;

    for (final row in rows) {
      if (row.createdAtMs >= cutoffCreatedAtMs) {
        continue;
      }
      await (db.delete(db.integrationsKeyValue)
            ..where((t) => t.id.equals(row.id)))
          .go();
      removed++;
    }

    final cap = maxEntries;
    if (cap == null || cap < 1) {
      return removed;
    }

    final remaining = await listIntegrationKeys(integrationId, keyPrefix: prefix);
    if (remaining.length <= cap) {
      return removed;
    }
    remaining.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    for (var i = cap; i < remaining.length; i++) {
      await (db.delete(db.integrationsKeyValue)
            ..where((t) => t.id.equals(remaining[i].id)))
          .go();
      removed++;
    }
    return removed;
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
      if (isGeneralOpenAiPromptLastCollectKey(key)) {
        return kIntegrationKvTypeIntMs;
      }
      if (key.startsWith(kIntegrationDeltaLinkKeyPrefix)) {
        return kIntegrationKvTypeDeltaLink;
      }
      if (key.contains('.history.') ||
          key.endsWith('.latest') && key.startsWith(kGeneralOpenAiPromptKeyPrefix)) {
        return kIntegrationKvTypeJson;
      }
      return kIntegrationKvTypeString;
  }
}
