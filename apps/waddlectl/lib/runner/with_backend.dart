import '../global_options.dart';
import '../local_drift_backend.dart';
import '../linux_secret_tool_store.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

Future<T> withLocalBackend<T>(
  GlobalCliOptions g,
  Future<T> Function(LocalDriftBackend) fn, {
  required bool productionSecrets,
}) async {
  final db = AppDatabase(createQueryExecutorForFile(g.databaseFile));
  final SecretStore secrets = productionSecrets
      ? createPlatformSecretStore()
      : InMemorySecretStore();
  final backend = LocalDriftBackend(db, secrets);
  try {
    return await fn(backend);
  } finally {
    await backend.close();
  }
}
