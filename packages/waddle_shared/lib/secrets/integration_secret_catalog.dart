import '../config/provider_config_resolver.dart';
import 'secret_store.dart';

/// UI / REST slot id for one operator-facing secret field.
class IntegrationSecretSlot {
  const IntegrationSecretSlot({
    required this.id,
    required this.label,
    required this.storageKey,
  });

  final String id;
  final String label;

  /// [SecretStore] key persisted in [IntegrationSecrets].
  final String storageKey;
}

const String kIntegrationSecretSlotApiKey = 'api_key';
const String kIntegrationSecretSlotClientId = 'client_id';

/// Google OAuth public client id ([SecretStore] key).
const String kGoogleClientIdSecretKey = 'provider:client_id:google';

/// Microsoft Graph OAuth public client id ([SecretStore] key).
const String kMicrosoftGraphClientIdSecretKey =
    'provider:client_id:microsoft_graph';

String providerAccessTokenSecretKey(String integrationId) =>
    '${ProviderConfigResolver.accessTokenKey}:$integrationId';

/// Slots shown in controller UI per integration id (empty = no secrets).
const Map<String, List<IntegrationSecretSlot>> kIntegrationSecretSlotsById = {
  'joke_openai': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotApiKey,
      label: 'OpenAI API key',
      storageKey: 'provider:access_token:joke_openai',
    ),
  ],
  'trivia_openai': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotApiKey,
      label: 'OpenAI API key',
      storageKey: 'provider:access_token:trivia_openai',
    ),
  ],
  'weather_openweathermap': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotApiKey,
      label: 'OpenWeatherMap API key',
      storageKey: 'provider:access_token:weather_openweathermap',
    ),
  ],
  'media_pexels': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotApiKey,
      label: 'Pexels API key',
      storageKey: 'provider:access_token:media_pexels',
    ),
  ],
  'media_flickr': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotApiKey,
      label: 'Flickr API key',
      storageKey: 'provider:access_token:media_flickr',
    ),
  ],
  'stock_finnhub': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotApiKey,
      label: 'Finnhub API key',
      storageKey: 'provider:access_token:stock_finnhub',
    ),
  ],
  'home_assistant': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotApiKey,
      label: 'Home Assistant long-lived access token',
      storageKey: 'provider:access_token:home_assistant',
    ),
  ],
  'calendar_google': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotClientId,
      label: 'Google OAuth client ID',
      storageKey: kGoogleClientIdSecretKey,
    ),
  ],
  'calendar_outlook': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotClientId,
      label: 'Microsoft Graph client ID',
      storageKey: kMicrosoftGraphClientIdSecretKey,
    ),
  ],
  'media_onedrive': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotClientId,
      label: 'Microsoft Graph client ID',
      storageKey: kMicrosoftGraphClientIdSecretKey,
    ),
  ],
};

List<IntegrationSecretSlot> integrationSecretSlotsFor(String integrationId) =>
    kIntegrationSecretSlotsById[integrationId] ?? const [];

List<IntegrationSecretSlot> requiredSecretSlotsFor(String integrationId) =>
    integrationSecretSlotsFor(integrationId);

IntegrationSecretSlot? integrationSecretSlotById(
  String integrationId,
  String slotId,
) {
  for (final slot in integrationSecretSlotsFor(integrationId)) {
    if (slot.id == slotId) {
      return slot;
    }
  }
  return null;
}

/// Whether every required slot has a non-empty value in [store].
Future<bool> isIntegrationSecretsFullyConfigured(
  SecretStore store,
  String integrationId,
) async {
  final slots = requiredSecretSlotsFor(integrationId);
  if (slots.isEmpty) {
    return true;
  }
  for (final slot in slots) {
    final v = await store.read(slot.storageKey);
    if (v == null || v.trim().isEmpty) {
      return false;
    }
  }
  return true;
}

/// Reads Google OAuth client id from [store].
Future<String?> readGoogleClientIdFromStore(SecretStore store) async {
  final v = await store.read(kGoogleClientIdSecretKey);
  final t = v?.trim();
  if (t == null || t.isEmpty) {
    return null;
  }
  return t;
}

/// Reads Microsoft Graph OAuth client id from [store].
Future<String?> readMicrosoftGraphClientIdFromStore(SecretStore store) async {
  final v = await store.read(kMicrosoftGraphClientIdSecretKey);
  final t = v?.trim();
  if (t == null || t.isEmpty) {
    return null;
  }
  return t;
}
