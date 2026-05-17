import 'package:test/test.dart';
import 'package:waddle_shared/secrets/db_encrypted_secret_store.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';
import 'package:waddle_shared/secrets/platform/in_memory_dek_protector.dart';

import '../helpers/memory_database.dart';

void main() {
  test('encrypts secrets at rest and round-trips read write delete', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final store = DbEncryptedSecretStore(
      db: db,
      protector: InMemoryDekProtector(),
    );

    const key = 'provider:access_token:default_joke_openai';
    await store.write(key, 'sk-test');
    expect(await store.read(key), 'sk-test');

    final all = await store.readAll();
    expect(all[key], 'sk-test');

    await store.delete(key);
    expect(await store.read(key), isNull);

    expect(
      await isIntegrationSecretsFullyConfigured(
        store,
        'default_joke_openai',
        integrationType: 'joke_openai',
      ),
      isFalse,
    );
    await store.write(key, 'sk-test');
    expect(
      await isIntegrationSecretsFullyConfigured(
        store,
        'default_joke_openai',
        integrationType: 'joke_openai',
      ),
      isTrue,
    );

    await db.close();
  });

  test('distinct DEK wraps produce independent ciphertext rows', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final store = DbEncryptedSecretStore(
      db: db,
      protector: InMemoryDekProtector(),
    );
    await store.write('a', 'one');
    await store.write('b', 'two');
    final rowA = await db.select(db.integrationSecrets).get();
    expect(rowA.length, 2);
    expect(rowA[0].ciphertext, isNot(equals(rowA[1].ciphertext)));
    await db.close();
  });
}
