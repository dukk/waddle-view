import 'integration_kv_repository.dart';
import 'integration_kv_types.dart';

/// Returns true when [pollSeconds] > 0 and [last_collect_ms] is still inside the window.
Future<bool> shouldSkipIntegrationPoll({
  required IntegrationKvRepository kv,
  required String integrationId,
  required int pollSeconds,
  required int nowMs,
}) async {
  if (pollSeconds <= 0) {
    return false;
  }
  final lastValue = await kv.getIntegrationValue(
    integrationId,
    kIntegrationLastCollectKey,
  );
  final last = int.tryParse(lastValue ?? '') ?? 0;
  return nowMs - last < pollSeconds * 1000;
}

/// Records [nowMs] as the last successful collect for [integrationId].
Future<void> markIntegrationCollectDone({
  required IntegrationKvRepository kv,
  required String integrationId,
  required int nowMs,
}) async {
  await kv.upsertIntegration(
    integrationId: integrationId,
    key: kIntegrationLastCollectKey,
    value: '$nowMs',
    valueType: kIntegrationKvTypeIntMs,
  );
}
