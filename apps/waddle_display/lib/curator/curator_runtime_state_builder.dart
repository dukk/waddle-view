import 'package:waddle_shared/curation/curator_runtime_state.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/runtime/runtime_signal_repository.dart';

/// Builds [CuratorRuntimeState] from SQLite, runtime signals, and future sensor hooks.
class CuratorRuntimeStateBuilder {
  const CuratorRuntimeStateBuilder({
    required this.db,
    this.signals,
  });

  final AppDatabase db;
  final RuntimeSignalRepository? signals;

  Future<CuratorRuntimeState> build() async {
    final clientCount = await db.select(db.apiClients).get();
    final repo = signals;
    if (repo == null) {
      return CuratorRuntimeState(
        displayAdopted: clientCount.isNotEmpty,
      );
    }
    final snap = await repo.snapshot();
    return CuratorRuntimeState(
      displayAdopted: clientCount.isNotEmpty,
      internetReachable: _boolFromSnap(snap, 'connectivity.internet_reachable') ?? true,
      displayServerReachable:
          _boolFromSnap(snap, 'connectivity.server_reachable') ?? true,
      motionDetected: _boolFromSnap(snap, 'room.motion_detected') ?? false,
      beaconDetected: _boolFromSnap(snap, 'beacon.present') ?? false,
    );
  }

  bool? _boolFromSnap(Map<String, dynamic> snap, String key) {
    final v = snap[key];
    if (v is bool) {
      return v;
    }
    if (v is Map && v['bool'] is bool) {
      return v['bool'] as bool;
    }
    return null;
  }
}
