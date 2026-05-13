import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';

import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/memory_database.dart';

void main() {
  test('merges drift row with secret token', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'p1',
            providerType: 't',
            baseUrl: const Value('https://example.com'),
          ),
        );
    final secrets = InMemorySecretStore();
    await secrets.write(
      '${ProviderConfigResolver.accessTokenKey}:p1',
      'tok',
    );
    final resolver = ProviderConfigResolver(db, secrets);
    final cfg = await resolver.resolve('p1');
    expect(cfg.accessToken, 'tok');
    expect(cfg.baseUrl, 'https://example.com');
    expect(cfg.describeForLogs(), contains('<redacted>'));
    await db.close();
  });
}
