import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/integrations/integration_poll_gate.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

AppDatabase _db() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

void main() {
  test('shouldSkipIntegrationPoll respects poll window', () async {
    final db = _db();
    await db.customStatement('SELECT 1');
    const integrationId = 'weather_openweathermap';
    await db
        .into(db.integrations)
        .insert(
          IntegrationsCompanion.insert(
            id: integrationId,
            integrationType: integrationId,
          ),
        );
    final kv = IntegrationKvRepository(db);
    await kv.upsertIntegration(
      integrationId: integrationId,
      key: kIntegrationLastCollectKey,
      value: '1000',
      valueType: kIntegrationKvTypeIntMs,
    );
    expect(
      await shouldSkipIntegrationPoll(
        kv: kv,
        integrationId: integrationId,
        pollSeconds: 900,
        nowMs: 2000,
      ),
      isTrue,
    );
    expect(
      await shouldSkipIntegrationPoll(
        kv: kv,
        integrationId: integrationId,
        pollSeconds: 900,
        nowMs: 1_000_000,
      ),
      isFalse,
    );
    expect(
      await shouldSkipIntegrationPoll(
        kv: kv,
        integrationId: integrationId,
        pollSeconds: 0,
        nowMs: 2000,
      ),
      isFalse,
    );
    await db.close();
  });
}
