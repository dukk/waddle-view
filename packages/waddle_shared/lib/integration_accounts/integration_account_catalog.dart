import '../config/google_kv.dart';
import '../config/microsoft_graph_kv.dart';

/// Stable id for a shared sign-in identity type (e.g. Google, Microsoft).
class IntegrationAccountTypeDefinition {
  const IntegrationAccountTypeDefinition({
    required this.id,
    required this.label,
    required this.signupUrl,
    required this.accountKeyField,
    required this.accessTokenSecretKey,
  });

  final String id;
  final String label;

  /// Operator-facing URL to create an account of this type.
  final String signupUrl;

  /// JSON field name under each `config_json.accounts[]` entry.
  final String accountKeyField;

  final String Function(String accountKey) accessTokenSecretKey;
}

const String kIntegrationAccountTypeGoogle = 'google';
const String kIntegrationAccountTypeMicrosoftGraph = 'microsoft_graph';

const Map<String, IntegrationAccountTypeDefinition> kIntegrationAccountTypes = {
  kIntegrationAccountTypeGoogle: IntegrationAccountTypeDefinition(
    id: kIntegrationAccountTypeGoogle,
    label: 'Google account',
    signupUrl: 'https://accounts.google.com/signup',
    accountKeyField: 'googleAccountKey',
    accessTokenSecretKey: googleAccessTokenSecret,
  ),
  kIntegrationAccountTypeMicrosoftGraph: IntegrationAccountTypeDefinition(
    id: kIntegrationAccountTypeMicrosoftGraph,
    label: 'Microsoft account',
    signupUrl: 'https://signup.live.com/',
    accountKeyField: 'graphAccountKey',
    accessTokenSecretKey: microsoftGraphAccessTokenSecret,
  ),
};

/// Integration types that authenticate via a shared [IntegrationAccountTypeDefinition].
const Map<String, List<String>> kIntegrationAccountRequirementsByType = {
  'calendar_google': [kIntegrationAccountTypeGoogle],
  'calendar_outlook': [kIntegrationAccountTypeMicrosoftGraph],
  'photo_onedrive': [kIntegrationAccountTypeMicrosoftGraph],
  'video_onedrive': [kIntegrationAccountTypeMicrosoftGraph],
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

String? accountTypeForIntegrationType(String integrationType) {
  final reqs = integrationAccountTypesRequiredForIntegration(integrationType);
  if (reqs.length == 1) {
    return reqs.single;
  }
  return null;
}
