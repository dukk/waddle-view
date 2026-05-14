import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/collect/data_collection_engine.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import 'helpers/callback_sleeper.dart';
import 'helpers/fake_blob_store.dart';
import 'helpers/memory_database.dart';

class CountingProvider implements IDataProvider {
  int count = 0;
  @override
  String get id => 'c';

  @override
  Future<void> collect(DataWriteContext ctx) async {
    count++;
  }
}

void main() {
  test('runs one provider then stops when sleeper stops engine', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(id: 'c', providerType: 'x'),
        );
    final secrets = InMemorySecretStore();
    final resolver = ProviderConfigResolver(db, {});
    final p = CountingProvider();
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );
    DataCollectionEngine? engineRef;
    engineRef = DataCollectionEngine(
      providers: [p],
      context: ctx,
      sleeper: CallbackSleeper(() => engineRef?.stop()),
      idleBetweenCycles: const Duration(days: 1),
    );
    await engineRef.start();
    expect(p.count, 1);
    await db.close();
  });

  test('onCycleComplete runs once per full provider round before idle', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(id: 'c', providerType: 'x'),
        );
    final secrets = InMemorySecretStore();
    final resolver = ProviderConfigResolver(db, {});
    final p = CountingProvider();
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: FakeBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
    );
    var cycles = 0;
    DataCollectionEngine? engineRef;
    engineRef = DataCollectionEngine(
      providers: [p],
      context: ctx,
      sleeper: CallbackSleeper(() => engineRef?.stop()),
      idleBetweenCycles: const Duration(days: 1),
      onCycleComplete: () async {
        cycles++;
      },
    );
    await engineRef.start();
    expect(p.count, 1);
    expect(cycles, 1);
    await db.close();
  });
}
