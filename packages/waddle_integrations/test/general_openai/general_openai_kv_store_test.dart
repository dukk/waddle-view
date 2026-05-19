import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_integrations/general_openai/general_openai_kv_store.dart';
import 'package:waddle_shared/integrations/general_openai_kv_keys.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  late AppDatabase db;
  late GeneralOpenAiKvStore store;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = GeneralOpenAiKvStore.fromDb(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: 'default_general_openai',
            integrationType: 'general_openai',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('writePromptResult stores latest and history keys', () async {
    const collectedAtMs = 1_700_000_000_000;
    await store.writePromptResult(
      integrationId: 'default_general_openai',
      promptId: 'daily_summary',
      value: '{"items":["a"]}',
      collectedAtMs: collectedAtMs,
      valueType: kIntegrationKvTypeJson,
    );

    final kv = IntegrationKvRepository(db);
    expect(
      await kv.getIntegrationValue(
        'default_general_openai',
        generalOpenAiPromptLatestKey('daily_summary'),
      ),
      '{"items":["a"]}',
    );
    expect(
      await kv.getIntegrationValue(
        'default_general_openai',
        generalOpenAiPromptHistoryKey('daily_summary', collectedAtMs),
      ),
      '{"items":["a"]}',
    );
    expect(
      await store.readPromptLastCollectMs(
        integrationId: 'default_general_openai',
        promptId: 'daily_summary',
      ),
      collectedAtMs,
    );
  });

  test('purgePromptHistory removes excess rows', () async {
    const nowMs = 1_700_100_000_000;
    final kv = IntegrationKvRepository(db);
    for (var i = 0; i < 5; i++) {
      await kv.insertIntegration(
        integrationId: 'default_general_openai',
        key: generalOpenAiPromptHistoryKey('daily_summary', nowMs - i * 1000),
        value: '{"i":$i}',
        valueType: kIntegrationKvTypeJson,
        createdAtMs: nowMs - i * 1000,
      );
    }

    final removed = await store.purgePromptHistory(
      integrationId: 'default_general_openai',
      promptId: 'daily_summary',
      retentionDays: 365,
      maxHistoryEntries: 2,
      nowMs: nowMs,
    );
    expect(removed, 3);

    final remaining = await kv.listIntegrationKeys(
      'default_general_openai',
      keyPrefix: generalOpenAiPromptHistoryPrefix('daily_summary'),
    );
    expect(remaining.length, 2);
  });
}
