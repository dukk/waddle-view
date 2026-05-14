import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;

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
