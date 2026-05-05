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
  final token = readJokesTokenFromDotenvMap(dotenv.env);
  if (token == null || token.isEmpty) {
    return;
  }
  await secrets.write(
    '${ProviderConfigResolver.accessTokenKey}:jokes',
    token,
  );
  AppDebugLog.startup('Dev .env: stored jokes provider token in SecretStore');
}
