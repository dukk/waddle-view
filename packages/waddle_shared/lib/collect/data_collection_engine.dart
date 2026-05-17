import 'collect_diagnostics.dart';
import 'data_provider.dart';
import 'data_write_context.dart';
import 'sleeper.dart';

/// Sequential round-robin over providers; never overlaps two collects.
class DataCollectionEngine {
  DataCollectionEngine({
    List<IDataProvider>? providers,
    Future<List<IDataProvider>> Function()? resolveProviders,
    required DataWriteContext context,
    required this.sleeper,
    required this.idleBetweenCycles,
    this.onCycleComplete,
    CollectDiagnostics diagnostics = const NoOpCollectDiagnostics(),
  })  : assert(
          providers != null || resolveProviders != null,
          'providers or resolveProviders required',
        ),
        _providers = providers == null ? null : List.unmodifiable(providers),
        _resolveProviders = resolveProviders,
        _context = context,
        _diagnostics = diagnostics;

  final List<IDataProvider>? _providers;
  final Future<List<IDataProvider>> Function()? _resolveProviders;
  final DataWriteContext _context;
  final Sleeper sleeper;
  final Duration idleBetweenCycles;
  final CollectDiagnostics _diagnostics;

  /// Invoked after each full round-robin over [providers], before idle sleep.
  final Future<void> Function()? onCycleComplete;

  bool _running = false;
  bool _collectInFlight = false;

  bool get collectInFlight => _collectInFlight;

  /// Runs until [stop] is called.
  Future<void> start() async {
    _running = true;
    final initial = await _currentProviders();
    _diagnostics.engine(
      'start: ${initial.length} provider(s), '
      'idleBetweenCycles=${idleBetweenCycles.inSeconds}s',
    );
    while (_running) {
      _diagnostics.engine('cycle begin');
      final cycleProviders = await _currentProviders();
      for (final p in cycleProviders) {
        if (!_running) {
          break;
        }
        await _runOne(p);
      }
      if (_running && onCycleComplete != null) {
        try {
          _diagnostics.engine('onCycleComplete begin');
          await onCycleComplete!();
          _diagnostics.engine('onCycleComplete ok');
        } on Object catch (e, st) {
          _diagnostics.engineFail('onCycleComplete', e, st);
        }
      }
      if (_running) {
        _diagnostics.engine(
          'sleep ${idleBetweenCycles.inSeconds}s until next cycle',
        );
        await sleeper.sleep(idleBetweenCycles);
      }
    }
    _diagnostics.engine('stop: loop exited');
  }

  Future<void> _runOne(IDataProvider p) async {
    _collectInFlight = true;
    _context.diagnostics.provider('collect begin id=${p.id}');
    try {
      await p.collect(_context);
      _context.diagnostics.provider('collect ok id=${p.id}');
    } on Object catch (e, st) {
      _context.diagnostics.providerFail('collect id=${p.id}', e, st);
    } finally {
      _collectInFlight = false;
    }
  }

  void stop() {
    if (_running) {
      _diagnostics.engine('stop requested');
    }
    _running = false;
  }

  Future<List<IDataProvider>> _currentProviders() async {
    if (_resolveProviders != null) {
      return _resolveProviders();
    }
    return _providers!;
  }
}
