import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

import 'fake_blob_store.dart';

/// Builds a [DataWriteContextImpl] for provider tests with [ProviderConfigResolver].
Future<DataWriteContextImpl> providerTestContext(
  AppDatabase db,
  InMemorySecretStore secrets, {
  Map<String, String> env = const {},
}) async {
  final resolver = ProviderConfigResolver(db, secrets);
  return DataWriteContextImpl(
    db: db,
    blobs: FakeBlobStore(),
    secrets: secrets,
    env: env,
    resolve: resolver.resolve,
  );
}

/// Same as [providerTestContext] but seeds a static API key for [integrationId].
Future<DataWriteContextImpl> providerTestContextWithApiKey(
  AppDatabase db,
  InMemorySecretStore secrets,
  String integrationId,
  String apiKey, {
  Map<String, String> env = const {},
}) async {
  await secrets.write(providerAccessTokenSecretKey(integrationId), apiKey);
  return providerTestContext(db, secrets, env: env);
}
