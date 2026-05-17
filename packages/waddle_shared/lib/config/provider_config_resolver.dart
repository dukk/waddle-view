import '../persistence/database.dart';
import '../secrets/integration_secret_catalog.dart';
import '../secrets/secret_store.dart';
import 'provider_runtime_config.dart';

class ProviderConfigResolver {
  ProviderConfigResolver(this._db, this._secrets);

  final AppDatabase _db;
  final SecretStore _secrets;

  /// Secret-store key prefix for static provider API tokens.
  static const accessTokenKey = 'provider:access_token';

  Future<ProviderRuntimeConfig> resolve(String providerId) async {
    final row =
        await (_db.select(
          _db.integrations,
        )..where((t) => t.id.equals(providerId))).getSingleOrNull();
    if (row == null) {
      throw StateError('Unknown provider $providerId');
    }
    final token = await _secrets.read(providerAccessTokenSecretKey(providerId));
    return ProviderRuntimeConfig(
      providerId: row.id,
      providerType: row.providerType,
      pollSeconds: row.pollSeconds,
      baseUrl: row.baseUrl,
      configJson: row.configJson,
      accessToken: token,
    );
  }
}
