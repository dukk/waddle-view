import 'dart:async';

/// Notifies the display shell when curator configuration or schedule changes.
///
/// Wired from REST [onConfigChanged] and from [WaddleHome] Drift watches so overlay
/// allowlists and merged membership stay in sync with SQLite.
class CuratorSelectionRefresh {
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  Future<void> notify() async {
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
  }
}
