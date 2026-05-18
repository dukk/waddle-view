import '../config/facebook_kv.dart';
import '../config/linkedin_kv.dart';
import '../config/twitter_kv.dart';
import '../secrets/integration_secret_catalog.dart';
import 'integration_account_catalog.dart';

/// Operator-facing OAuth app registration (public client id) per cloud provider.
class OAuthProviderDefinition {
  const OAuthProviderDefinition({
    required this.id,
    required this.label,
    required this.clientIdStorageKey,
    required this.accountTypeId,
  });

  final String id;
  final String label;
  final String clientIdStorageKey;
  final String accountTypeId;
}

const String kOAuthProviderIdGoogle = 'google';
const String kOAuthProviderIdMicrosoftGraph = 'microsoft_graph';
const String kOAuthProviderIdFacebook = 'facebook';
const String kOAuthProviderIdTwitter = 'twitter';
const String kOAuthProviderIdLinkedin = 'linkedin';

const List<OAuthProviderDefinition> kOAuthProviders = [
  OAuthProviderDefinition(
    id: kOAuthProviderIdGoogle,
    label: 'Google',
    clientIdStorageKey: kGoogleClientIdSecretKey,
    accountTypeId: kIntegrationAccountTypeGoogle,
  ),
  OAuthProviderDefinition(
    id: kOAuthProviderIdMicrosoftGraph,
    label: 'Microsoft',
    clientIdStorageKey: kMicrosoftGraphClientIdSecretKey,
    accountTypeId: kIntegrationAccountTypeMicrosoftGraph,
  ),
  OAuthProviderDefinition(
    id: kOAuthProviderIdFacebook,
    label: 'Facebook',
    clientIdStorageKey: kFacebookClientIdSecretKey,
    accountTypeId: kIntegrationAccountTypeFacebook,
  ),
  OAuthProviderDefinition(
    id: kOAuthProviderIdTwitter,
    label: 'X (Twitter)',
    clientIdStorageKey: kTwitterClientIdSecretKey,
    accountTypeId: kIntegrationAccountTypeTwitter,
  ),
  OAuthProviderDefinition(
    id: kOAuthProviderIdLinkedin,
    label: 'LinkedIn',
    clientIdStorageKey: kLinkedInClientIdSecretKey,
    accountTypeId: kIntegrationAccountTypeLinkedin,
  ),
];

OAuthProviderDefinition? oauthProviderById(String providerId) {
  for (final p in kOAuthProviders) {
    if (p.id == providerId) {
      return p;
    }
  }
  return null;
}

OAuthProviderDefinition? oauthProviderForAccountType(String accountTypeId) {
  for (final p in kOAuthProviders) {
    if (p.accountTypeId == accountTypeId) {
      return p;
    }
  }
  return null;
}
