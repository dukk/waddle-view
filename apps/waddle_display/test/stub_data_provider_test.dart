import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_display/data/data_write_context.dart';
import 'package:waddle_display/data/stub_data_provider.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import 'helpers/fake_blob_store.dart';
import 'helpers/memory_database.dart';

void main() {
  test('collect writes kv and blob metadata', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(id: 'stub', providerType: 'stub'),
        );
    final secrets = InMemorySecretStore();
    final resolver = ProviderConfigResolver(db, secrets);
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );
    await StubDataProvider().collect(ctx);
    final row =
        await (db.select(db.configKeyValues)
              ..where((t) => t.key.equals('header.title')))
            .getSingle();
    expect(row.value, 'Waddle View');
    final blobs = await db.select(db.blobMetadata).get();
    expect(blobs, isNotEmpty);
    await db.close();
  });
}
