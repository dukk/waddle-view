import 'package:waddle_shared/curation/curator_configuration_loader.dart';
import 'package:waddle_shared/curation/curator_schedule_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'curator_runtime_state_builder.dart';

/// Resolves layered curator selection for the display process.
class ActiveCuratorService {
  ActiveCuratorService({
    required AppDatabase db,
    CuratorRuntimeStateBuilder? stateBuilder,
  }) : _db = db,
       _stateBuilder = stateBuilder ?? CuratorRuntimeStateBuilder(db: db);

  final AppDatabase _db;
  final CuratorRuntimeStateBuilder _stateBuilder;

  Future<ResolvedCuratorSelection> resolveAt(DateTime localNow) async {
    final state = await _stateBuilder.build();
    final configs = await loadCuratorConfigurationInputs(_db);
    return CuratorScheduleResolver.resolve(
      localNow: localNow,
      state: state,
      configurations: configs,
    );
  }
}
