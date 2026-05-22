import 'package:test/test.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

void main() {
  test('integrationSecretSlotsForIntegration rewrites api_key storage key', () {
    final slots = integrationSecretSlotsForIntegration(
      'pexels_home',
      'photo_pexels',
    );
    expect(slots, isEmpty);

    final google = integrationSecretSlotsForIntegration(
      'cal_google',
      'calendar_google',
    );
    expect(google, hasLength(1));
    expect(google.single.id, kIntegrationSecretSlotClientId);
    expect(google.single.storageKey, kGoogleClientIdSecretKey);
  });

  test('integrationSecretSlotById finds slot by id', () {
    final slot = integrationSecretSlotById(
      'cal_google',
      'calendar_google',
      kIntegrationSecretSlotClientId,
    );
    expect(slot, isNotNull);
    expect(
      integrationSecretSlotById('cal_google', 'calendar_google', 'missing'),
      isNull,
    );
  });

  test('isIntegrationSecretsFullyConfigured requires all slots', () async {
    final store = InMemorySecretStore();
    expect(
      await isIntegrationSecretsFullyConfigured(
        store,
        'cal_google',
        integrationType: 'calendar_google',
      ),
      isFalse,
    );
    await store.write(kGoogleClientIdSecretKey, 'client-id');
    expect(
      await isIntegrationSecretsFullyConfigured(
        store,
        'cal_google',
        integrationType: 'calendar_google',
      ),
      isTrue,
    );
    expect(
      await isIntegrationSecretsFullyConfigured(
        store,
        'stub',
        integrationType: 'stub',
      ),
      isTrue,
    );
  });

  test('read client id helpers return trimmed values', () async {
    final store = InMemorySecretStore();
    await store.write(kGoogleClientIdSecretKey, '  g  ');
    await store.write(kMicrosoftGraphClientIdSecretKey, '');
    expect(await readGoogleClientIdFromStore(store), 'g');
    expect(await readMicrosoftGraphClientIdFromStore(store), isNull);
  });
}
