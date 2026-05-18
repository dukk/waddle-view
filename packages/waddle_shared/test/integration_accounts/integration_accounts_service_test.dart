import 'package:test/test.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/integration_accounts/integration_accounts_service.dart';

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
  });
}
