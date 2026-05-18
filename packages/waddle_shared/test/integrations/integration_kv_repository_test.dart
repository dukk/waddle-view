import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  late AppDatabase db;
  late IntegrationKvRepository kv;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    kv = IntegrationKvRepository(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: 'test_pexels',
            integrationType: 'photo_pexels',
          ),
        );
    await db.into(db.integrationAccounts).insert(
          IntegrationAccountsCompanion.insert(
            id: 'acct_google',
            accountType: 'google',
            createdAtMs: 1,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('upsertIntegration creates and updates with fresh updatedAtMs', () async {
    await kv.upsertIntegration(
      integrationId: 'test_pexels',
      key: kIntegrationLastCollectKey,
      value: '100',
      valueType: kIntegrationKvTypeIntMs,
    );
    final first = await (db.select(db.integrationsKeyValue)
          ..where((t) => t.integrationId.equals('test_pexels')))
        .getSingle();
    expect(first.createdAtMs, first.updatedAtMs);
    expect(first.value, '100');

    await Future<void>.delayed(const Duration(milliseconds: 2));
    await kv.upsertIntegration(
      integrationId: 'test_pexels',
      key: kIntegrationLastCollectKey,
      value: '200',
    );
    final second = await (db.select(db.integrationsKeyValue)
          ..where((t) => t.integrationId.equals('test_pexels')))
        .getSingle();
    expect(second.value, '200');
    expect(second.updatedAtMs, greaterThanOrEqualTo(first.updatedAtMs));
    expect(second.createdAtMs, first.createdAtMs);
  });

  test('getAccountValue and deleteAccountKey', () async {
    await kv.upsertAccount(
      accountId: 'acct_google',
      key: kIntegrationAccessTokenExpiresAtKey,
      value: '999',
      valueType: kIntegrationKvTypeIntMs,
    );
    expect(
      await kv.getAccountValue('acct_google', kIntegrationAccessTokenExpiresAtKey),
      '999',
    );
    await kv.deleteAccountKey('acct_google', kIntegrationAccessTokenExpiresAtKey);
    expect(
      await kv.getAccountValue('acct_google', kIntegrationAccessTokenExpiresAtKey),
      isNull,
    );
  });

  test('integration and account rows are independent', () async {
    await kv.upsertIntegration(
      integrationId: 'test_pexels',
      key: kIntegrationLastCollectKey,
      value: '1',
    );
    await kv.upsertAccount(
      accountId: 'acct_google',
      key: kIntegrationLastCollectKey,
      value: '2',
    );
    expect(await kv.getIntegrationValue('test_pexels', kIntegrationLastCollectKey), '1');
    expect(await kv.getAccountValue('acct_google', kIntegrationLastCollectKey), '2');
  });
}
