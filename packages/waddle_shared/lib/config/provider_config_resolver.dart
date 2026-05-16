import '../persistence/database.dart';
import 'provider_access_token_env.dart';
import 'provider_runtime_config.dart';

class ProviderConfigResolver {
  ProviderConfigResolver(this._db, this._env);

  final AppDatabase _db;

  /// Merged `Platform.environment` and optional debug `.env` entries.
  final Map<String, String> _env;

  /// Legacy secret-store key prefix (OAuth and docs); static API keys use env.
  static const accessTokenKey = 'provider:access_token';

  Future<ProviderRuntimeConfig> resolve(String providerId) async {
    final row =
        await (_db.select(
          _db.integrations,
        )..where((t) => t.id.equals(providerId))).getSingleOrNull();
    if (row == null) {
      throw StateError('Unknown provider $providerId');
    }
    final token = resolveProviderAccessTokenFromEnv(providerId, _env);
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
