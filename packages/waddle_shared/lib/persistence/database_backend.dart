import 'dart:io';

/// Which SQL backend backs [AppDatabase].
enum WaddleDatabaseBackend {
  sqlite,
  postgres,
}

/// Reads `WADDLE_DISPLAY_DATABASE_URL` when set (Postgres); otherwise SQLite.
WaddleDatabaseBackend waddleDatabaseBackendFromEnvironment([
  Map<String, String>? env,
]) {
  final source = env ?? Platform.environment;
  final url = source['WADDLE_DISPLAY_DATABASE_URL']?.trim();
  if (url != null && url.isNotEmpty) {
    return WaddleDatabaseBackend.postgres;
  }
  return WaddleDatabaseBackend.sqlite;
}

const kWaddleDisplayDatabaseUrlEnv = 'WADDLE_DISPLAY_DATABASE_URL';
