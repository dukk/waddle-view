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
  }) : _providers = List.unmodifiable(providers),
       _context = context,
       _sleeper = sleeper,
       _idleBetweenCycles = idleBetweenCycles;

  final List<IDataProvider> _providers;
  final DataWriteContext _context;
  final Sleeper _sleeper;
  final Duration _idleBetweenCycles;

  bool _running = false;
  bool _collectInFlight = false;

  bool get collectInFlight => _collectInFlight;

  /// Runs until [stop] is called.
  Future<void> start() async {
    _running = true;
    while (_running) {
      for (final p in _providers) {
        if (!_running) {
          break;
        }
        await _runOne(p);
      }
      if (_running) {
        await _sleeper.sleep(_idleBetweenCycles);
      }
    }
  }

  Future<void> _runOne(IDataProvider p) async {
    _collectInFlight = true;
    try {
      await p.collect(_context);
    } on Object {
      // Policy: log via zone / caller; continue loop.
    } finally {
      _collectInFlight = false;
    }
  }

  void stop() {
    _running = false;
  }
}
