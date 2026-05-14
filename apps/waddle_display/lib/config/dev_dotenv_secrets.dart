import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;
import 'package:waddle_shared/config/provider_access_token_env.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

import '../debug/app_debug_log.dart';
import 'google_kv.dart';
import 'microsoft_graph_kv.dart';

export 'package:waddle_shared/config/provider_access_token_env.dart';

/// Loads `.env` from disk in **debug** desktop/server builds only (not web).
///
/// Searches, in order (first hit wins): `.env`, `.env.development`, `assets/.env`,
/// `assets/.env.development`, then monorepo `apps/waddle_display/` variants of those paths.
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
    p.join('apps', 'waddle_display', '.env'),
    p.join('apps', 'waddle_display', '.env.development'),
    p.join('apps', 'waddle_display', 'assets', '.env'),
    p.join('apps', 'waddle_display', 'assets', '.env.development'),
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

/// Process environment merged with [dotenv] (when initialized); dotenv entries
/// override duplicate keys so local `.env` wins over empty platform values.
Map<String, String> mergeBootstrapEnv() {
  final m = Map<String, String>.from(Platform.environment);
  if (dotenv.isInitialized) {
    for (final e in dotenv.env.entries) {
      m[e.key] = e.value;
    }
  }
  return m;
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
