import '../blob/blob_store.dart';
import '../config/provider_runtime_config.dart';
import '../persistence/database.dart';
import '../secrets/secret_store.dart';

/// What [IDataProvider.collect] may touch during a tick.
abstract class DataWriteContext {
  AppDatabase get db;

  BlobStore get blobs;

  SecretStore get secrets;

  Future<ProviderRuntimeConfig> resolveConfig(String providerId);
}

class DataWriteContextImpl implements DataWriteContext {
  DataWriteContextImpl({
    required this.db,
    required this.blobs,
    required this.secrets,
    required Future<ProviderRuntimeConfig> Function(String providerId) resolve,
  }) : _resolve = resolve;

  final Future<ProviderRuntimeConfig> Function(String providerId) _resolve;

  @override
  final AppDatabase db;

  @override
  final BlobStore blobs;

  @override
  final SecretStore secrets;

  @override
  Future<ProviderRuntimeConfig> resolveConfig(String providerId) =>
      _resolve(providerId);
}
