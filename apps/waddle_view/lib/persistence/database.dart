import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    ProviderSettings,
    BlobMetadata,
    DashboardAlerts,
    DashboardKv,
    TickerScreens,
    TickerConditionGroups,
    TickerConditions,
    TickerScreenRuntimes,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await customStatement('''
CREATE VIEW IF NOT EXISTS v_dashboard_alert_active_candidates AS
SELECT *
FROM dashboard_alerts
WHERE dismissed_at IS NULL
ORDER BY priority DESC, created_at DESC;
''');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );
}

/// Opens a file-backed SQLite database under application support.
QueryExecutor createQueryExecutor() {
  return LazyDatabase(() async {
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'waddle_view.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
