import 'package:test/test.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/integration_accounts/oauth_provider_catalog.dart';

void main() {
  test('every oauth sign-in account type has an oauth provider entry', () {
    final oauthAccountTypes = kIntegrationAccountTypes.values
        .where((t) => t.supportsOAuthSignIn)
        .map((t) => t.id)
        .toList();
    expect(oauthAccountTypes, hasLength(5));

    for (final accountTypeId in oauthAccountTypes) {
      final provider = oauthProviderForAccountType(accountTypeId);
      expect(provider, isNotNull, reason: 'missing provider for $accountTypeId');
      expect(provider!.accountTypeId, accountTypeId);
    }
  });

  test('kOAuthProviders includes social news providers', () {
    final ids = kOAuthProviders.map((p) => p.id).toList();
    expect(ids, containsAll(['google', 'microsoft_graph', 'facebook', 'twitter', 'linkedin']));
  });
}
