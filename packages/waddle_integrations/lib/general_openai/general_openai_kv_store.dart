import 'package:waddle_shared/integrations/general_openai_kv_keys.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/persistence/database.dart';

/// Writes and purges [general_openai] prompt results in [IntegrationsKeyValue].
class GeneralOpenAiKvStore {
  GeneralOpenAiKvStore(this._kv);

  final IntegrationKvRepository _kv;

  factory GeneralOpenAiKvStore.fromDb(AppDatabase db) =>
      GeneralOpenAiKvStore(IntegrationKvRepository(db));

  Future<void> writePromptResult({
    required String integrationId,
    required String promptId,
    required String value,
    required int collectedAtMs,
    required String valueType,
  }) async {
    await _kv.upsertIntegration(
      integrationId: integrationId,
      key: generalOpenAiPromptLatestKey(promptId),
      value: value,
      valueType: valueType,
    );
    await _kv.insertIntegration(
      integrationId: integrationId,
      key: generalOpenAiPromptHistoryKey(promptId, collectedAtMs),
      value: value,
      valueType: valueType,
      createdAtMs: collectedAtMs,
    );
    await _kv.upsertIntegration(
      integrationId: integrationId,
      key: generalOpenAiPromptLastCollectKey(promptId),
      value: '$collectedAtMs',
      valueType: kIntegrationKvTypeIntMs,
    );
    await _kv.deleteIntegrationKey(
      integrationId,
      generalOpenAiPromptLastErrorKey(promptId),
    );
  }

  Future<void> writePromptError({
    required String integrationId,
    required String promptId,
    required String message,
    required int atMs,
  }) async {
    await _kv.upsertIntegration(
      integrationId: integrationId,
      key: generalOpenAiPromptLastErrorKey(promptId),
      value: message,
      valueType: kIntegrationKvTypeString,
    );
    await _kv.upsertIntegration(
      integrationId: integrationId,
      key: generalOpenAiPromptLastCollectKey(promptId),
      value: '$atMs',
      valueType: kIntegrationKvTypeIntMs,
    );
  }

  Future<int?> readPromptLastCollectMs({
    required String integrationId,
    required String promptId,
  }) async {
    final raw = await _kv.getIntegrationValue(
      integrationId,
      generalOpenAiPromptLastCollectKey(promptId),
    );
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw);
  }

  Future<int> purgePromptHistory({
    required String integrationId,
    required String promptId,
    required int retentionDays,
    required int maxHistoryEntries,
    required int nowMs,
  }) async {
    if (retentionDays < 1 && maxHistoryEntries < 1) {
      return 0;
    }
    final cutoffMs = retentionDays > 0
        ? nowMs - retentionDays * 86400000
        : 0;
    return _kv.purgeIntegrationHistoryKeys(
      integrationId: integrationId,
      historyKeyPrefix: generalOpenAiPromptHistoryPrefix(promptId),
      cutoffCreatedAtMs: cutoffMs,
      maxEntries: maxHistoryEntries > 0 ? maxHistoryEntries : null,
    );
  }
}
