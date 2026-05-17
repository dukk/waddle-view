import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';

import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/memory_database.dart';
import '../helpers/secret_test_helpers.dart';

void main() {
  test('merges drift row with secret store token', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.integrations).insert(
          IntegrationsCompanion.insert(
            id: 'weather_openweathermap',
            providerType: 'weather_openweathermap',
            baseUrl: const Value('https://example.com'),
          ),
        );
    final secrets = InMemorySecretStore();
    await seedIntegrationApiKeyForTest(
      secrets,
      'weather_openweathermap',
      'tok',
    );
    final resolver = ProviderConfigResolver(db, secrets);
    final cfg = await resolver.resolve('weather_openweathermap');
    expect(cfg.accessToken, 'tok');
    expect(cfg.baseUrl, 'https://example.com');
    expect(cfg.describeForLogs(), contains('<redacted>'));
    await db.close();
  });
}
