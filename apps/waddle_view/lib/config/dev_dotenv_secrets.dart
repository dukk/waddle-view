import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;

import '../debug/app_debug_log.dart';
import '../secrets/secret_store.dart';
import 'google_kv.dart';
import 'microsoft_graph_kv.dart';
import 'provider_config_resolver.dart';

/// Reads the jokes/OpenAI token from a merged env map.
///
/// Prefer [`waddleJokesAccessTokenKey`] when set; otherwise [`openAiApiKeyEnv`].
String? readJokesTokenFromDotenvMap(Map<String, String> map) {
  final explicit = map[waddleJokesAccessTokenKey]?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }
  final openai = map[openAiApiKeyEnv]?.trim();
  if (openai != null && openai.isNotEmpty) {
    return openai;
  }
  return null;
}

/// Env key for an OpenAI-style API token (common ecosystem convention).
const String openAiApiKeyEnv = 'OPENAI_API_KEY';

/// Optional explicit key so a shared `.env` can scope the joke provider token.
const String waddleJokesAccessTokenKey = 'WADDLE_JOKES_ACCESS_TOKEN';

/// Optional override for the trivia provider; otherwise same resolution as jokes.
const String waddleTriviaAccessTokenKey = 'WADDLE_TRIVIA_ACCESS_TOKEN';

/// API key for OpenWeatherMap weather provider.
const String openWeatherMapApiKeyEnv = 'OPEN_WEATHER_MAP_API_KEY';

/// Pexels API key (https://www.pexels.com/api/).
const String pexelsApiKeyEnv = 'PEXELS_API_KEY';

/// Optional explicit Pexels key (otherwise [pexelsApiKeyEnv]).
const String waddlePexelsAccessTokenKey = 'WADDLE_PEXELS_ACCESS_TOKEN';

/// Finnhub API key (https://finnhub.io/) for the `stocks` provider.
const String finnhubApiKeyEnv = 'FINNHUB_API_KEY';

/// Optional explicit Finnhub key (otherwise [finnhubApiKeyEnv]).
const String waddleStocksAccessTokenKey = 'WADDLE_STOCKS_ACCESS_TOKEN';

/// Prefix for Microsoft Graph OAuth tokens in debug `.env` files.
///
/// Pair with [waddleMsGraphRefreshTokenPrefix]: for account key `work`, set
/// `WADDLE_MSGRAPH_ACCESS_TOKEN_work` and optionally `WADDLE_MSGRAPH_REFRESH_TOKEN_work`.
const String waddleMsGraphAccessTokenPrefix = 'WADDLE_MSGRAPH_ACCESS_TOKEN_';

/// See [waddleMsGraphAccessTokenPrefix].
const String waddleMsGraphRefreshTokenPrefix = 'WADDLE_MSGRAPH_REFRESH_TOKEN_';

/// Prefix for Google OAuth access tokens in debug `.env` files.
const String waddleGoogleAccessTokenPrefix = 'WADDLE_GOOGLE_ACCESS_TOKEN_';

/// Prefix for Google OAuth refresh tokens in debug `.env` files.
const String waddleGoogleRefreshTokenPrefix = 'WADDLE_GOOGLE_REFRESH_TOKEN_';

/// OpenAI-style token for trivia: explicit trivia key, else same as jokes/OpenAI.
String? readTriviaTokenFromDotenvMap(Map<String, String> map) {
  final explicit = map[waddleTriviaAccessTokenKey]?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }
  return readJokesTokenFromDotenvMap(map);
}

/// Weather provider token from dotenv map.
String? readWeatherTokenFromDotenvMap(Map<String, String> map) {
  final weather = map[openWeatherMapApiKeyEnv]?.trim();
  if (weather != null && weather.isNotEmpty) {
    return weather;
  }
  return null;
}

/// Pexels provider API key from dotenv map.
String? readPexelsTokenFromDotenvMap(Map<String, String> map) {
  final explicit = map[waddlePexelsAccessTokenKey]?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }
  final p = map[pexelsApiKeyEnv]?.trim();
  if (p != null && p.isNotEmpty) {
    return p;
  }
  return null;
}

/// Stocks provider token from dotenv map: explicit override, else
/// [finnhubApiKeyEnv].
String? readStocksTokenFromDotenvMap(Map<String, String> map) {
  final explicit = map[waddleStocksAccessTokenKey]?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }
  final f = map[finnhubApiKeyEnv]?.trim();
  if (f != null && f.isNotEmpty) {
    return f;
  }
  return null;
}

/// Loads `.env` from disk in **debug** desktop/server builds only (not web).
///
/// Searches, in order (first hit wins): `.env`, `.env.development`, `assets/.env`,
/// `assets/.env.development`, then monorepo `apps/waddle_view/` variants of those paths.
/// If none exist, initializes an empty [dotenv] so callers can query safely.
Future<void> loadDevDotenvFromFilesystem() async {
  if (!kDebugMode || kIsWeb) {
    return;
  }
  final candidates = [
    '.env',
    '.env.development',
    p.join('assets', '.env'),
    p.join('assets', '.env.development'),
    // Monorepo: `flutter run` from repo root with `--project` / cwd at workspace root
    p.join('apps', 'waddle_view', '.env'),
    p.join('apps', 'waddle_view', '.env.development'),
    p.join('apps', 'waddle_view', 'assets', '.env'),
    p.join('apps', 'waddle_view', 'assets', '.env.development'),
  ];
  for (final rel in candidates) {
    final file = File(rel);
    if (await file.exists()) {
      final content = await file.readAsString();
      dotenv.loadFromString(
        envString: content,
        isOptional: true,
      );
      return;
    }
  }
  dotenv.loadFromString(envString: '', isOptional: true);
}

/// Writes the jokes provider token from [dotenv] into [secrets] when running in
/// **debug** mode. Intended for local onboarding via `.env` (never committed).
///
/// When a token is present in the env file, it **overwrites** the stored secret
/// so rotating keys in `.env` + restart is enough; release builds never call this.
Future<void> applyJokesTokenFromDevDotenv(SecretStore secrets) async {
  if (!kDebugMode) {
    return;
  }
  if (!dotenv.isInitialized) {
    return;
  }
  final jokesToken = readJokesTokenFromDotenvMap(dotenv.env);
  if (jokesToken != null && jokesToken.isNotEmpty) {
    await secrets.write(
      '${ProviderConfigResolver.accessTokenKey}:jokes',
      jokesToken,
    );
    AppDebugLog.startup('Dev .env: stored jokes provider token in SecretStore');
  }
  final triviaToken = readTriviaTokenFromDotenvMap(dotenv.env);
  if (triviaToken != null && triviaToken.isNotEmpty) {
    await secrets.write(
      '${ProviderConfigResolver.accessTokenKey}:trivia',
      triviaToken,
    );
    AppDebugLog.startup('Dev .env: stored trivia provider token in SecretStore');
  }
  final weatherToken = readWeatherTokenFromDotenvMap(dotenv.env);
  if (weatherToken != null && weatherToken.isNotEmpty) {
    await secrets.write(
      '${ProviderConfigResolver.accessTokenKey}:weather',
      weatherToken,
    );
    AppDebugLog.startup('Dev .env: stored weather provider token in SecretStore');
  }
  final pexelsToken = readPexelsTokenFromDotenvMap(dotenv.env);
  if (pexelsToken != null && pexelsToken.isNotEmpty) {
    await secrets.write(
      '${ProviderConfigResolver.accessTokenKey}:pexels',
      pexelsToken,
    );
    AppDebugLog.startup('Dev .env: stored Pexels provider API key in SecretStore');
  }
  final stocksToken = readStocksTokenFromDotenvMap(dotenv.env);
  if (stocksToken != null && stocksToken.isNotEmpty) {
    await secrets.write(
      '${ProviderConfigResolver.accessTokenKey}:stocks',
      stocksToken,
    );
    AppDebugLog.startup('Dev .env: stored stocks provider API key in SecretStore');
  }
}

/// Writes Microsoft Graph OAuth tokens from [dotenv] into [secrets] when
/// running in **debug** mode. Keys: `WADDLE_MSGRAPH_ACCESS_TOKEN_<accountKey>`
/// and optional `WADDLE_MSGRAPH_REFRESH_TOKEN_<accountKey>` where `<accountKey>`
/// matches `graphAccountKey` in the Outlook calendar provider `config_json`.
Future<void> applyMicrosoftGraphTokensFromDevDotenv(SecretStore secrets) async {
  if (!kDebugMode) {
    return;
  }
  if (!dotenv.isInitialized) {
    return;
  }
  var wrote = false;
  for (final e in dotenv.env.entries) {
    final k = e.key;
    if (!k.startsWith(waddleMsGraphAccessTokenPrefix)) {
      continue;
    }
    final accountKey = k.substring(waddleMsGraphAccessTokenPrefix.length).trim();
    if (accountKey.isEmpty) {
      continue;
    }
    final access = e.value.trim();
    if (access.isEmpty) {
      continue;
    }
    await secrets.write(
      microsoftGraphAccessTokenSecret(accountKey),
      access,
    );
    wrote = true;
    final refreshKey = '$waddleMsGraphRefreshTokenPrefix$accountKey';
    final refresh = dotenv.env[refreshKey]?.trim();
    if (refresh != null && refresh.isNotEmpty) {
      await secrets.write(
        microsoftGraphRefreshTokenSecret(accountKey),
        refresh,
      );
    }
  }
  if (wrote) {
    AppDebugLog.startup(
      'Dev .env: stored Microsoft Graph token(s) in SecretStore',
    );
  }
}

/// Writes Google OAuth tokens from [dotenv] into [secrets] when running in
/// **debug** mode. Keys: `WADDLE_GOOGLE_ACCESS_TOKEN_<accountKey>` and optional
/// `WADDLE_GOOGLE_REFRESH_TOKEN_<accountKey>`.
Future<void> applyGoogleTokensFromDevDotenv(SecretStore secrets) async {
  if (!kDebugMode) {
    return;
  }
  if (!dotenv.isInitialized) {
    return;
  }
  var wrote = false;
  for (final e in dotenv.env.entries) {
    final k = e.key;
    if (!k.startsWith(waddleGoogleAccessTokenPrefix)) {
      continue;
    }
    final accountKey = k.substring(waddleGoogleAccessTokenPrefix.length).trim();
    if (accountKey.isEmpty) {
      continue;
    }
    final access = e.value.trim();
    if (access.isEmpty) {
      continue;
    }
    await secrets.write(
      googleAccessTokenSecret(accountKey),
      access,
    );
    wrote = true;
    final refreshKey = '$waddleGoogleRefreshTokenPrefix$accountKey';
    final refresh = dotenv.env[refreshKey]?.trim();
    if (refresh != null && refresh.isNotEmpty) {
      await secrets.write(
        googleRefreshTokenSecret(accountKey),
        refresh,
      );
    }
  }
  if (wrote) {
    AppDebugLog.startup('Dev .env: stored Google token(s) in SecretStore');
  }
}
