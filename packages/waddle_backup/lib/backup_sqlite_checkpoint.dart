import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Flushes WAL into the main DB file so a single-file backup is consistent.
Future<void> walCheckpointFull(File sqliteFile) async {
  final db = sqlite3.open(
    sqliteFile.path,
    mode: OpenMode.readWriteCreate,
  );
  try {
    db.execute('PRAGMA wal_checkpoint(FULL);');
  } finally {
    db.close();
  }
}
