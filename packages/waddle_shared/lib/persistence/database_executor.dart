import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_postgres/drift_postgres.dart';
import 'package:postgres/postgres.dart' as pg;

import 'database.dart';
import 'database_backend.dart';

/// Opens SQLite at [sqliteFile] (default backend for CLI tools).
QueryExecutor createSqliteExecutorForFile(File sqliteFile) {
  return LazyDatabase(() async {
    return NativeDatabase.createInBackground(sqliteFile);
  });
}

/// Legacy alias used by waddlectl and backup tooling.
QueryExecutor createQueryExecutorForFile(File sqliteFile) =>
    createSqliteExecutorForFile(sqliteFile);

/// Reads [WADDLE_DISPLAY_DATABASE_URL] from [env] when set; otherwise null.
String? waddleDisplayDatabaseUrlFromEnvironment([Map<String, String>? env]) {
  final source = env ?? Platform.environment;
  final url = source[kWaddleDisplayDatabaseUrlEnv]?.trim();
  if (url == null || url.isEmpty) return null;
  return url;
}

/// Parses a Postgres URL into a [pg.Endpoint].
pg.Endpoint postgresEndpointFromUrl(String databaseUrl) {
  final uri = Uri.parse(databaseUrl);
  if (uri.scheme != 'postgres' && uri.scheme != 'postgresql') {
    throw ArgumentError(
      'WADDLE_DISPLAY_DATABASE_URL must use postgres:// or postgresql://',
    );
  }
  final userInfo = uri.userInfo.split(':');
  final username = userInfo.isNotEmpty
      ? Uri.decodeComponent(userInfo.first)
      : '';
  final password = userInfo.length > 1
      ? Uri.decodeComponent(userInfo.sublist(1).join(':'))
      : '';
  final dbName = uri.pathSegments.isNotEmpty
      ? uri.pathSegments.last
      : 'postgres';
  return pg.Endpoint(
    host: uri.host.isEmpty ? 'localhost' : uri.host,
    port: uri.hasPort ? uri.port : 5432,
    database: dbName,
    username: username.isEmpty ? null : username,
    password: password.isEmpty ? null : password,
  );
}

QueryExecutor createPostgresExecutorFromUrl(String databaseUrl) {
  return PgDatabase(endpoint: postgresEndpointFromUrl(databaseUrl));
}

/// Picks SQLite file or Postgres URL from environment.
({QueryExecutor executor, WaddleDatabaseBackend backend})
createDisplayExecutor({Map<String, String>? env, File? sqliteFile}) {
  final url = waddleDisplayDatabaseUrlFromEnvironment(env);
  if (url != null) {
    return (
      executor: createPostgresExecutorFromUrl(url),
      backend: WaddleDatabaseBackend.postgres,
    );
  }
  if (sqliteFile == null) {
    throw ArgumentError(
      'sqliteFile is required when WADDLE_DISPLAY_DATABASE_URL is unset',
    );
  }
  return (
    executor: createSqliteExecutorForFile(sqliteFile),
    backend: WaddleDatabaseBackend.sqlite,
  );
}

AppDatabase openAppDatabase({Map<String, String>? env, File? sqliteFile}) {
  final resolved = createDisplayExecutor(env: env, sqliteFile: sqliteFile);
  return AppDatabase(resolved.executor, backend: resolved.backend);
}
