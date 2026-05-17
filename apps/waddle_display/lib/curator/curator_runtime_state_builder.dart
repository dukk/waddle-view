import 'package:waddle_shared/curation/curator_runtime_state.dart';
import 'package:waddle_shared/persistence/database.dart';

/// Builds [CuratorRuntimeState] from SQLite and future sensor hooks.
class CuratorRuntimeStateBuilder {
  const CuratorRuntimeStateBuilder({required this.db});

  final AppDatabase db;

  Future<CuratorRuntimeState> build() async {
    final clientCount = await db.select(db.apiClients).get();
    return CuratorRuntimeState(
      displayAdopted: clientCount.isNotEmpty,
    );
  }
}
