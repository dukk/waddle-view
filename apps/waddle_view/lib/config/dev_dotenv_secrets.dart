import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;

import '../debug/app_debug_log.dart';
import '../secrets/secret_store.dart';
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
}
