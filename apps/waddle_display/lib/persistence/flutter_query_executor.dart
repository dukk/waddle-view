import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/database_backend.dart';
import 'package:waddle_shared/persistence/database_executor.dart';

import '../debug/app_debug_log.dart';

/// Opens the display database (SQLite file under app support, or Postgres when configured).
QueryExecutor createQueryExecutor() {
  final url = waddleDisplayDatabaseUrlFromEnvironment();
  if (url != null) {
    AppDebugLog.startup(
      'PostgreSQL database: configured via WADDLE_DISPLAY_DATABASE_URL',
    );
    return createPostgresExecutorFromUrl(url);
  }
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'waddle_display.db'));
    AppDebugLog.startup('SQLite database file: ${file.path}');
    return NativeDatabase.createInBackground(file);
  });
}

WaddleDatabaseBackend displayDatabaseBackend() =>
    waddleDatabaseBackendFromEnvironment();

/// Opens [AppDatabase] with backend detection from environment.
Future<AppDatabase> openDisplayDatabase({File? sqliteFile}) async {
  final url = waddleDisplayDatabaseUrlFromEnvironment();
  if (url != null) {
    AppDebugLog.startup(
      'PostgreSQL database: configured via WADDLE_DISPLAY_DATABASE_URL',
    );
    return AppDatabase(
      createPostgresExecutorFromUrl(url),
      backend: WaddleDatabaseBackend.postgres,
    );
  }
  final file =
      sqliteFile ??
      File(
        p.join(
          (await getApplicationSupportDirectory()).path,
          'waddle_display.db',
        ),
      );
  AppDebugLog.startup('SQLite database file: ${file.path}');
  return AppDatabase(
    createSqliteExecutorForFile(file),
    backend: WaddleDatabaseBackend.sqlite,
  );
}
