import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../debug/app_debug_log.dart';

/// Opens a file-backed SQLite database under application support.
QueryExecutor createQueryExecutor() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'waddle_view.sqlite'));
    AppDebugLog.startup('SQLite database file: ${file.path}');
    return NativeDatabase.createInBackground(file);
  });
}
