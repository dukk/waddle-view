import 'dart:async';

/// Returns immediately while [work] runs in the background.
///
/// REST handlers that `await onConfigChanged()` can respond before heavy
/// ticker/curator refresh completes (avoids proxy timeouts on the controller).
Future<void> scheduleDeferredConfigChanged(Future<void> Function() work) async {
  unawaited(work());
}
