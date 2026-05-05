import '../../debug/app_debug_log.dart';
import '../../sleeper.dart';
import '../data_provider.dart';
import '../data_write_context.dart';

/// Sequential round-robin over providers; never overlaps two collects.
class DataCollectionEngine {
  DataCollectionEngine({
    required List<IDataProvider> providers,
    required DataWriteContext context,
    required Sleeper sleeper,
    required Duration idleBetweenCycles,
    this.onCycleComplete,
  }) : _providers = List.unmodifiable(providers),
       _context = context,
       _sleeper = sleeper,
       _idleBetweenCycles = idleBetweenCycles;

  final List<IDataProvider> _providers;
  final DataWriteContext _context;
  final Sleeper _sleeper;
  final Duration _idleBetweenCycles;

  /// Invoked after each full round-robin over [providers], before idle sleep.
  final Future<void> Function()? onCycleComplete;

  bool _running = false;
  bool _collectInFlight = false;

  bool get collectInFlight => _collectInFlight;

  /// Runs until [stop] is called.
  Future<void> start() async {
    _running = true;
    AppDebugLog.engine(
      'start: ${_providers.length} provider(s), '
      'idleBetweenCycles=${_idleBetweenCycles.inSeconds}s',
    );
    while (_running) {
      AppDebugLog.engine('cycle begin');
      for (final p in _providers) {
        if (!_running) {
          break;
        }
        await _runOne(p);
      }
      if (_running && onCycleComplete != null) {
        try {
          AppDebugLog.engine('onCycleComplete begin');
          await onCycleComplete!();
          AppDebugLog.engine('onCycleComplete ok');
        } on Object catch (e, st) {
          AppDebugLog.engineFail('onCycleComplete', e, st);
        }
      }
      if (_running) {
        AppDebugLog.engine(
          'sleep ${_idleBetweenCycles.inSeconds}s until next cycle',
        );
        await _sleeper.sleep(_idleBetweenCycles);
      }
    }
    AppDebugLog.engine('stop: loop exited');
  }

  Future<void> _runOne(IDataProvider p) async {
    _collectInFlight = true;
    AppDebugLog.engine('collect begin id=${p.id}');
    try {
      await p.collect(_context);
      AppDebugLog.engine('collect ok id=${p.id}');
    } on Object catch (e, st) {
      AppDebugLog.engineFail('collect id=${p.id}', e, st);
    } finally {
      _collectInFlight = false;
    }
  }

  void stop() {
    if (_running) {
      AppDebugLog.engine('stop requested');
    }
    _running = false;
  }
}
