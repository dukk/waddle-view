import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Queues navigation requests from REST (same semantics as display arrow keys).
final class DisplayNavigationBus extends ChangeNotifier {
  final ListQueue<int> _screenDirs = ListQueue<int>();
  final ListQueue<int> _tickerDirs = ListQueue<int>();

  /// -1 = back / left, +1 = forward / right.
  void enqueueScreenNav(int direction) {
    if (direction != -1 && direction != 1) {
      return;
    }
    _screenDirs.addLast(direction);
    notifyListeners();
  }

  /// -1 = backward / up, +1 = forward / down.
  void enqueueTickerNav(int direction) {
    if (direction != -1 && direction != 1) {
      return;
    }
    _tickerDirs.addLast(direction);
    notifyListeners();
  }

  int? dequeueScreenNav() =>
      _screenDirs.isEmpty ? null : _screenDirs.removeFirst();

  int? dequeueTickerNav() =>
      _tickerDirs.isEmpty ? null : _tickerDirs.removeFirst();
}
