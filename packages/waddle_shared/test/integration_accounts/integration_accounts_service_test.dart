import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/integration_accounts/integration_accounts_service.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

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
}
