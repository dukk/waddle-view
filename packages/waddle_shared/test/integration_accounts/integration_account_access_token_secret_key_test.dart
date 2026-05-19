import 'package:test/test.dart';
import 'package:waddle_shared/config/facebook_kv.dart';
import 'package:waddle_shared/config/google_kv.dart';
import 'package:waddle_shared/config/linkedin_kv.dart';
import 'package:waddle_shared/config/microsoft_graph_kv.dart';
import 'package:waddle_shared/config/twitter_kv.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/integration_accounts/integration_accounts_configured_sql.dart';

void main() {
  test('SQL secret-key CASE matches catalog accessTokenSecretKey builders', () {
    const accountId = 'acct-key-alignment';
    final expectedByType = <String, String>{
      kIntegrationAccountTypeGoogle: googleAccessTokenSecret(accountId),
      kIntegrationAccountTypeMicrosoftGraph:
          microsoftGraphAccessTokenSecret(accountId),
      kIntegrationAccountTypeFacebook: facebookAccessTokenSecret(accountId),
      kIntegrationAccountTypeTwitter: twitterAccessTokenSecret(accountId),
      kIntegrationAccountTypeLinkedin: linkedInAccessTokenSecret(accountId),
      kIntegrationAccountTypeApiKeyPexels: 'provider:access_token:$accountId',
    };

    for (final entry in expectedByType.entries) {
      final def = kIntegrationAccountTypes[entry.key]!;
      expect(
        def.accessTokenSecretKey(accountId),
        entry.value,
        reason: 'Dart builder for ${entry.key}',
      );
    }

    expect(
      kIntegrationAccountAccessTokenSecretKeySqlCase,
      contains("WHEN 'google' THEN 'provider:access_token:google:' || a.id"),
    );
    expect(
      kIntegrationAccountAccessTokenSecretKeySqlCase,
      contains(
        "WHEN 'microsoft_graph' THEN 'provider:access_token:microsoft_graph:' || a.id",
      ),
    );
    expect(
      kIntegrationAccountAccessTokenSecretKeySqlCase,
      contains("ELSE 'provider:access_token:' || a.id"),
    );
  });
}
