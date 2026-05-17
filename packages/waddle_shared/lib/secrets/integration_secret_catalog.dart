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

/// Slots shown in controller UI per [Integrations.integrationType].
const Map<String, List<IntegrationSecretSlot>> kIntegrationSecretSlotsByType = {
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
  'photo_pexels': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotApiKey,
      label: 'Pexels API key',
      storageKey: 'provider:access_token:photo_pexels',
    ),
  ],
  'video_pexels': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotApiKey,
      label: 'Pexels API key',
      storageKey: 'provider:access_token:video_pexels',
    ),
  ],
  'photo_flickr': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotApiKey,
      label: 'Flickr API key',
      storageKey: 'provider:access_token:photo_flickr',
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
  'photo_onedrive': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotClientId,
      label: 'Microsoft Graph client ID',
      storageKey: kMicrosoftGraphClientIdSecretKey,
    ),
  ],
  'video_onedrive': [
    IntegrationSecretSlot(
      id: kIntegrationSecretSlotClientId,
      label: 'Microsoft Graph client ID',
      storageKey: kMicrosoftGraphClientIdSecretKey,
    ),
  ],
};

List<IntegrationSecretSlot> integrationSecretSlotsForType(String integrationType) =>
    kIntegrationSecretSlotsByType[integrationType] ?? const [];

List<IntegrationSecretSlot> integrationSecretSlotsForIntegration(
  String integrationId,
  String integrationType,
) {
  return [
    for (final slot in integrationSecretSlotsForType(integrationType))
      if (slot.id == kIntegrationSecretSlotApiKey)
        IntegrationSecretSlot(
          id: slot.id,
          label: slot.label,
          storageKey: providerAccessTokenSecretKey(integrationId),
        )
      else
        slot,
  ];
}

IntegrationSecretSlot? integrationSecretSlotById(
  String integrationId,
  String integrationType,
  String slotId,
) {
  for (final slot in integrationSecretSlotsForIntegration(
    integrationId,
    integrationType,
  )) {
    if (slot.id == slotId) {
      return slot;
    }
  }
  return null;
}

Future<bool> isIntegrationSecretsFullyConfigured(
  SecretStore store,
  String integrationId, {
  required String integrationType,
}) async {
  final slots = integrationSecretSlotsForIntegration(integrationId, integrationType);
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

Future<String?> readGoogleClientIdFromStore(SecretStore store) async {
  final v = await store.read(kGoogleClientIdSecretKey);
  final t = v?.trim();
  if (t == null || t.isEmpty) {
    return null;
  }
  return t;
}

Future<String?> readMicrosoftGraphClientIdFromStore(SecretStore store) async {
  final v = await store.read(kMicrosoftGraphClientIdSecretKey);
  final t = v?.trim();
  if (t == null || t.isEmpty) {
    return null;
  }
  return t;
}
