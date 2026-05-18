import '../config/facebook_kv.dart';
import '../config/google_kv.dart';
import '../config/linkedin_kv.dart';
import '../config/microsoft_graph_kv.dart';
import '../config/provider_config_resolver.dart';
import '../config/twitter_kv.dart';

/// Stable id for a shared sign-in identity type (e.g. Google, Microsoft, API key).
class IntegrationAccountTypeDefinition {
  const IntegrationAccountTypeDefinition({
    required this.id,
    required this.label,
    this.signupUrl,
    this.accountKeyField,
    required this.accessTokenSecretKey,
    this.supportsOAuthSignIn = false,
  });

  final String id;
  final String label;

  /// Operator-facing URL to create an account of this type (OAuth types).
  final String? signupUrl;

  /// JSON field name under each `config_json.accounts[]` entry (OAuth types).
  final String? accountKeyField;

  final String Function(String accountKey) accessTokenSecretKey;

  /// When true, tokens are obtained via device-code OAuth on the display.
  final bool supportsOAuthSignIn;
}

const String kIntegrationAccountTypeGoogle = 'google';
const String kIntegrationAccountTypeMicrosoftGraph = 'microsoft_graph';
const String kIntegrationAccountTypeApiKeyOpenAi = 'api_key_openai';
const String kIntegrationAccountTypeApiKeyOpenWeatherMap =
    'api_key_openweathermap';
const String kIntegrationAccountTypeApiKeyPexels = 'api_key_pexels';
const String kIntegrationAccountTypeApiKeyFlickr = 'api_key_flickr';
const String kIntegrationAccountTypeApiKeyFinnhub = 'api_key_finnhub';
const String kIntegrationAccountTypeApiKeyHomeAssistant =
    'api_key_home_assistant';
const String kIntegrationAccountTypeFacebook = 'facebook';
const String kIntegrationAccountTypeTwitter = 'twitter';
const String kIntegrationAccountTypeLinkedin = 'linkedin';

String _apiKeyAccessTokenSecret(String accountKey) =>
    '${ProviderConfigResolver.accessTokenKey}:$accountKey';

const Map<String, IntegrationAccountTypeDefinition> kIntegrationAccountTypes = {
  kIntegrationAccountTypeGoogle: IntegrationAccountTypeDefinition(
    id: kIntegrationAccountTypeGoogle,
    label: 'Google account',
    signupUrl: 'https://accounts.google.com/signup',
    accountKeyField: 'googleAccountKey',
    accessTokenSecretKey: googleAccessTokenSecret,
    supportsOAuthSignIn: true,
  ),
  kIntegrationAccountTypeMicrosoftGraph: IntegrationAccountTypeDefinition(
    id: kIntegrationAccountTypeMicrosoftGraph,
    label: 'Microsoft account',
    signupUrl: 'https://signup.live.com/',
    accountKeyField: 'graphAccountKey',
    accessTokenSecretKey: microsoftGraphAccessTokenSecret,
    supportsOAuthSignIn: true,
  ),
  kIntegrationAccountTypeApiKeyOpenAi: IntegrationAccountTypeDefinition(
    id: kIntegrationAccountTypeApiKeyOpenAi,
    label: 'OpenAI API key',
    accessTokenSecretKey: _apiKeyAccessTokenSecret,
  ),
  kIntegrationAccountTypeApiKeyOpenWeatherMap:
      IntegrationAccountTypeDefinition(
    id: kIntegrationAccountTypeApiKeyOpenWeatherMap,
    label: 'OpenWeatherMap API key',
    signupUrl: 'https://home.openweathermap.org/users/sign_up',
    accessTokenSecretKey: _apiKeyAccessTokenSecret,
  ),
  kIntegrationAccountTypeApiKeyPexels: IntegrationAccountTypeDefinition(
    id: kIntegrationAccountTypeApiKeyPexels,
    label: 'Pexels API key',
    signupUrl: 'https://www.pexels.com/join/',
    accessTokenSecretKey: _apiKeyAccessTokenSecret,
  ),
  kIntegrationAccountTypeApiKeyFlickr: IntegrationAccountTypeDefinition(
    id: kIntegrationAccountTypeApiKeyFlickr,
    label: 'Flickr API key',
    signupUrl: 'https://www.flickr.com/signup',
    accessTokenSecretKey: _apiKeyAccessTokenSecret,
  ),
  kIntegrationAccountTypeApiKeyFinnhub: IntegrationAccountTypeDefinition(
    id: kIntegrationAccountTypeApiKeyFinnhub,
    label: 'Finnhub API key',
    signupUrl: 'https://finnhub.io/register',
    accessTokenSecretKey: _apiKeyAccessTokenSecret,
  ),
  kIntegrationAccountTypeApiKeyHomeAssistant:
      IntegrationAccountTypeDefinition(
    id: kIntegrationAccountTypeApiKeyHomeAssistant,
    label: 'Home Assistant token',
    accessTokenSecretKey: _apiKeyAccessTokenSecret,
  ),
  kIntegrationAccountTypeFacebook: IntegrationAccountTypeDefinition(
    id: kIntegrationAccountTypeFacebook,
    label: 'Facebook account',
    signupUrl: 'https://www.facebook.com/',
    accountKeyField: 'facebookAccountKey',
    accessTokenSecretKey: facebookAccessTokenSecret,
    supportsOAuthSignIn: true,
  ),
  kIntegrationAccountTypeTwitter: IntegrationAccountTypeDefinition(
    id: kIntegrationAccountTypeTwitter,
    label: 'X (Twitter) account',
    signupUrl: 'https://x.com/i/flow/signup',
    accountKeyField: 'twitterAccountKey',
    accessTokenSecretKey: twitterAccessTokenSecret,
    supportsOAuthSignIn: true,
  ),
  kIntegrationAccountTypeLinkedin: IntegrationAccountTypeDefinition(
    id: kIntegrationAccountTypeLinkedin,
    label: 'LinkedIn account',
    signupUrl: 'https://www.linkedin.com/signup',
    accountKeyField: 'linkedInAccountKey',
    accessTokenSecretKey: linkedInAccessTokenSecret,
    supportsOAuthSignIn: true,
  ),
};

/// Integration types that authenticate via a shared [IntegrationAccountTypeDefinition].
const Map<String, List<String>> kIntegrationAccountRequirementsByType = {
  'calendar_google': [kIntegrationAccountTypeGoogle],
  'calendar_outlook': [kIntegrationAccountTypeMicrosoftGraph],
  'photo_onedrive': [kIntegrationAccountTypeMicrosoftGraph],
  'video_onedrive': [kIntegrationAccountTypeMicrosoftGraph],
  'joke_openai': [kIntegrationAccountTypeApiKeyOpenAi],
  'trivia_openai': [kIntegrationAccountTypeApiKeyOpenAi],
  'weather_openweathermap': [kIntegrationAccountTypeApiKeyOpenWeatherMap],
  'photo_pexels': [kIntegrationAccountTypeApiKeyPexels],
  'video_pexels': [kIntegrationAccountTypeApiKeyPexels],
  'photo_flickr': [kIntegrationAccountTypeApiKeyFlickr],
  'stock_finnhub': [kIntegrationAccountTypeApiKeyFinnhub],
  'home_assistant': [kIntegrationAccountTypeApiKeyHomeAssistant],
  'news_facebook': [kIntegrationAccountTypeFacebook],
  'news_twitter': [kIntegrationAccountTypeTwitter],
  'news_linkedin': [kIntegrationAccountTypeLinkedin],
};

List<String> integrationAccountTypesRequiredForIntegration(String integrationType) =>
    kIntegrationAccountRequirementsByType[integrationType] ?? const [];

/// Integration types that use the given shared account type.
List<String> integrationTypesForAccountType(String accountTypeId) {
  final out = <String>[];
  for (final entry in kIntegrationAccountRequirementsByType.entries) {
    if (entry.value.contains(accountTypeId)) {
      out.add(entry.key);
    }
  }
  out.sort();
  return out;
}

IntegrationAccountTypeDefinition? integrationAccountTypeDefinition(String accountTypeId) =>
    kIntegrationAccountTypes[accountTypeId];

/// Primary account type for [integrationType] when exactly one is required.
String? accountTypeForIntegrationType(String integrationType) {
  final reqs = integrationAccountTypesRequiredForIntegration(integrationType);
  if (reqs.length == 1) {
    return reqs.single;
  }
  return null;
}

/// Default account id for API-key integrations (one account per integration row).
String defaultApiKeyAccountIdForIntegration(String integrationId) => integrationId;

bool integrationTypeUsesApiKeyAccount(String integrationType) {
  final typeId = accountTypeForIntegrationType(integrationType);
  if (typeId == null) {
    return false;
  }
  return kIntegrationAccountTypes[typeId]?.supportsOAuthSignIn != true;
}
