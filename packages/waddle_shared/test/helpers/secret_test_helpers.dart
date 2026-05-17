import 'package:waddle_shared/secrets/integration_secret_catalog.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

/// Seeds a static provider API key for tests ([ProviderConfigResolver]).
Future<void> seedIntegrationApiKeyForTest(
  SecretStore store,
  String integrationId,
  String apiKey,
) =>
    store.write(providerAccessTokenSecretKey(integrationId), apiKey);

Future<void> seedGoogleClientIdForTest(SecretStore store, String clientId) =>
    store.write(kGoogleClientIdSecretKey, clientId);

Future<void> seedMicrosoftGraphClientIdForTest(
  SecretStore store,
  String clientId,
) =>
    store.write(kMicrosoftGraphClientIdSecretKey, clientId);
