import '../blob/blob_store.dart';
import '../config/provider_runtime_config.dart';
import '../secrets/secret_store.dart';
import 'collect_diagnostics.dart';
import '../persistence/database.dart';

/// What [IDataProvider.collect] may touch during a tick.
abstract class DataWriteContext {
  AppDatabase get db;

  BlobStore get blobs;

  SecretStore get secrets;

  CollectDiagnostics get diagnostics;

  /// Merged process environment (and optional debug `.env`), used for OAuth
  /// public client ids and static provider API keys — never OAuth refresh
  /// material for Google / Microsoft Graph (those use [secrets] only).
  Map<String, String> get env;

  Future<ProviderRuntimeConfig> resolveConfig(String providerId);
}

class DataWriteContextImpl implements DataWriteContext {
  DataWriteContextImpl({
    required this.db,
    required this.blobs,
    required this.secrets,
    required Future<ProviderRuntimeConfig> Function(String providerId) resolve,
    this.env = const {},
    this.diagnostics = const NoOpCollectDiagnostics(),
  }) : _resolve = resolve;

  final Future<ProviderRuntimeConfig> Function(String providerId) _resolve;

  @override
  final AppDatabase db;

  @override
  final BlobStore blobs;

  @override
  final SecretStore secrets;

  @override
  final CollectDiagnostics diagnostics;

  @override
  final Map<String, String> env;

  @override
  Future<ProviderRuntimeConfig> resolveConfig(String providerId) =>
      _resolve(providerId);
}
