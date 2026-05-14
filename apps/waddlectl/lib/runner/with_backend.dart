import '../global_options.dart';
import '../local_drift_backend.dart';
import 'package:waddle_shared/persistence/database.dart';

Future<T> withLocalBackend<T>(
  GlobalCliOptions g,
  Future<T> Function(LocalDriftBackend) fn,
) async {
  final db = AppDatabase(createQueryExecutorForFile(g.databaseFile));
  final backend = LocalDriftBackend(db);
  try {
    return await fn(backend);
  } finally {
    await backend.close();
  }
}
