import 'package:flutter/foundation.dart';

import '../clock.dart';
import '../sleeper.dart';
import 'ticker_condition_evaluator.dart';
import 'ticker_schedule_repository.dart';

/// Sequential rotation with dwell; call [start] unawaited from the UI isolate.
class TickerRotationController extends ChangeNotifier {
  TickerRotationController({
    required TickerScheduleRepository repository,
    required TickerConditionEvaluator evaluator,
    required Clock clock,
    required Sleeper sleeper,
  }) : _repository = repository,
       _evaluator = evaluator,
       _clock = clock,
       _sleeper = sleeper;

  final TickerScheduleRepository _repository;
  final TickerConditionEvaluator _evaluator;
  final Clock _clock;
  final Sleeper _sleeper;

  bool _running = false;
  int _index = 0;
  String? _label;

  String? get currentLabel => _label;

  bool get isRunning => _running;

  Future<void> start() async {
    _running = true;
    while (_running) {
      final bundles = await _repository.loadBundles();
      final now = _clock.now();
      final eligible = bundles
          .where((b) => _evaluator.isEligible(now, b))
          .toList();
      if (eligible.isEmpty) {
        if (_label != null) {
          _label = null;
          notifyListeners();
        }
        await _sleeper.sleep(const Duration(seconds: 1));
        continue;
      }
      _index %= eligible.length;
      final b = eligible[_index];
      _index++;
      _label = b.screen.bodyText ?? b.screen.id;
      notifyListeners();
      final tickStart = _clock.now();
      await _repository.onShowStart(b.screen.id, tickStart);
      await _sleeper.sleep(Duration(milliseconds: b.screen.dwellMs));
      if (!_running) {
        break;
      }
      await _repository.onShowEnd(b.screen.id, _clock.now());
    }
  }

  void stop() {
    _running = false;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
