import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/integration_accounts/integration_accounts_service.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/config/google_kv.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

import '../helpers/memory_database.dart';

void main() {
  test('accountKeysInIntegrationConfig reads google and graph keys', () {
    expect(
      accountKeysInIntegrationConfig(
        'calendar_google',
        '{"accounts":[{"googleAccountKey":"a","sources":[]},'
        '{"googleAccountKey":"  "}]}',
      ).toList(),
      ['a'],
    );
    expect(
      accountKeysInIntegrationConfig(
        'photo_onedrive',
        '{"accounts":[{"graphAccountKey":"ms1","sources":[]}]}',
      ).toList(),
      ['ms1'],
    );
    expect(
      accountKeysInIntegrationConfig('photo_pexels', '{"accounts":[]}').toList(),
      isEmpty,
    );
  });

  test('integration types share microsoft account type', () {
    expect(
      integrationTypesForAccountType(kIntegrationAccountTypeMicrosoftGraph),
      containsAll(['calendar_outlook', 'photo_onedrive', 'video_onedrive']),
    );
    expect(
      integrationAccountTypesRequiredForIntegration('calendar_google'),
      [kIntegrationAccountTypeGoogle],
    );
    expect(
      integrationAccountTypesRequiredForIntegration('photo_pexels'),
      [kIntegrationAccountTypeApiKeyPexels],
    );
  });

  test('syncIntegrationAccountLinks links api key account per integration row', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final secrets = InMemorySecretStore();
    addTearDown(db.close);
    await db.into(db.integrations).insertOnConflictUpdate(
      IntegrationsCompanion.insert(
        id: 'pexels_home',
        integrationType: 'photo_pexels',
      ),
    );
    await syncIntegrationAccountLinks(db);
    final links = await (db.select(db.integrationAccountLinks)
          ..where((t) => t.integrationId.equals('pexels_home')))
        .get();
    expect(links, hasLength(1));
    expect(links.single.accountId, 'pexels_home');
    await secrets.write('provider:access_token:pexels_home', 'key-123');
    expect(
      await integrationAccountsSatisfiedForEnable(
        secrets,
        db,
        'pexels_home',
        'photo_pexels',
      ),
      isTrue,
    );
    expect(
      await readAccessTokenForIntegration(secrets, db, 'pexels_home'),
      'key-123',
    );
  });

  test('createOperatorIntegrationAccount stores api key account and links integrations',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final secrets = InMemorySecretStore();
    addTearDown(db.close);
    await db.into(db.integrations).insertOnConflictUpdate(
      IntegrationsCompanion.insert(
        id: 'pexels_home',
        integrationType: 'photo_pexels',
      ),
    );
    final accountId = await createOperatorIntegrationAccount(
      db,
      secrets,
      accountTypeId: kIntegrationAccountTypeApiKeyPexels,
    );
    expect(accountId, kIntegrationAccountTypeApiKeyPexels);
    await secrets.write(
      'provider:access_token:$accountId',
      'pexels-key',
    );
    final items = await listIntegrationAccountsJson(db, secrets);
    expect(items, hasLength(1));
    expect(items.single['id'], accountId);
    expect(items.single['configured'], isTrue);
  });

  test('createOperatorIntegrationAccount requires oauth client id', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final secrets = InMemorySecretStore();
    addTearDown(db.close);
    expect(
      () => createOperatorIntegrationAccount(
        db,
        secrets,
        accountTypeId: kIntegrationAccountTypeGoogle,
        accountKey: 'personal',
      ),
      throwsStateError,
    );
    await secrets.write(kGoogleClientIdSecretKey, 'google-client');
    final accountId = await createOperatorIntegrationAccount(
      db,
      secrets,
      accountTypeId: kIntegrationAccountTypeGoogle,
      accountKey: 'personal',
      label: 'Personal',
    );
    expect(accountId, 'personal');
    final row = await (db.select(db.integrationAccounts)
          ..where((t) => t.id.equals('personal')))
        .getSingle();
    expect(row.accountType, kIntegrationAccountTypeGoogle);
  });

  test('deleteOperatorIntegrationAccount blocks when linked without confirm',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final secrets = InMemorySecretStore();
    addTearDown(db.close);
    await secrets.write(kGoogleClientIdSecretKey, 'google-client');
    await db.into(db.integrations).insertOnConflictUpdate(
      IntegrationsCompanion.insert(
        id: 'calendar_google_home',
        integrationType: 'calendar_google',
        enabled: const Value(true),
        configJson: Value(
          '{"accounts":[{"googleAccountKey":"personal","sources":[]}]}',
        ),
      ),
    );
    await createOperatorIntegrationAccount(
      db,
      secrets,
      accountTypeId: kIntegrationAccountTypeGoogle,
      accountKey: 'personal',
    );
    expect(
      () => deleteOperatorIntegrationAccount(db, secrets, accountId: 'personal'),
      throwsA(isA<IntegrationAccountInUseException>()),
    );
  });

  test('deleteOperatorIntegrationAccount removes oauth account and disables integrations',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final secrets = InMemorySecretStore();
    addTearDown(db.close);
    await secrets.write(kGoogleClientIdSecretKey, 'google-client');
    const integrationId = 'calendar_google_home';
    await db.into(db.integrations).insertOnConflictUpdate(
      IntegrationsCompanion.insert(
        id: integrationId,
        integrationType: 'calendar_google',
        enabled: const Value(true),
        configJson: Value(
          '{"accounts":[{"googleAccountKey":"personal","sources":[]}]}',
        ),
      ),
    );
    await createOperatorIntegrationAccount(
      db,
      secrets,
      accountTypeId: kIntegrationAccountTypeGoogle,
      accountKey: 'personal',
    );
    await secrets.write(googleAccessTokenSecret('personal'), 'token');
    final result = await deleteOperatorIntegrationAccount(
      db,
      secrets,
      accountId: 'personal',
      confirm: true,
    );
    expect(result.disabledIntegrationIds, [integrationId]);
    expect(
      await (db.select(db.integrationAccounts)
            ..where((t) => t.id.equals('personal')))
          .get(),
      isEmpty,
    );
    final row = await (db.select(db.integrations)
          ..where((t) => t.id.equals(integrationId)))
        .getSingle();
    expect(row.enabled, isFalse);
    expect(
      accountKeysInIntegrationConfig(row.integrationType, row.configJson).toList(),
      isEmpty,
    );
    expect(await secrets.read(googleAccessTokenSecret('personal')), isNull);
  });

  test('deleteOperatorIntegrationAccount allows unused account without confirm',
      () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final secrets = InMemorySecretStore();
    addTearDown(db.close);
    await createOperatorIntegrationAccount(
      db,
      secrets,
      accountTypeId: kIntegrationAccountTypeApiKeyPexels,
      accountKey: 'unused_pexels',
    );
    await deleteOperatorIntegrationAccount(
      db,
      secrets,
      accountId: 'unused_pexels',
    );
    expect(
      await (db.select(db.integrationAccounts)
            ..where((t) => t.id.equals('unused_pexels')))
          .get(),
      isEmpty,
    );
  });

  test('updateOperatorIntegrationAccountLabel changes display name', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    addTearDown(db.close);
    final secrets = InMemorySecretStore();
    await createOperatorIntegrationAccount(
      db,
      secrets,
      accountTypeId: kIntegrationAccountTypeApiKeyPexels,
      accountKey: 'pexels_home',
      label: 'Old',
    );
    await updateOperatorIntegrationAccountLabel(db, 'pexels_home', label: 'Pexels home');
    final row = await (db.select(db.integrationAccounts)
          ..where((t) => t.id.equals('pexels_home')))
        .getSingle();
    expect(row.label, 'Pexels home');
  });
}
