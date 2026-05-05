import 'dart:async';

import 'debug/app_debug_log.dart';

/// Ensures the next ticker curation waits until the UI marquee has finished at
/// least one full scroll loop for the **previous** curated row set (or the
/// strip is static, e.g. empty).
class MarqueeCycleGate {
  MarqueeCycleGate({
    Duration presentationWaitTimeout = const Duration(minutes: 2),
  }) : _presentationWaitTimeout = presentationWaitTimeout;

  final Duration _presentationWaitTimeout;

  Completer<void>? _marqueeMustCompleteBeforeNextCuration;

  /// Await this **before** applying new curation when a prior curation armed
  /// a wait (see [onCurationWrittenExpectMarqueeLoop]).
  Future<void> awaitPriorMarqueePresentationIfAny() async {
    final c = _marqueeMustCompleteBeforeNextCuration;
    if (c == null || c.isCompleted) {
      return;
    }
    try {
      await c.future.timeout(_presentationWaitTimeout);
    } on TimeoutException catch (_) {
      AppDebugLog.curator(
        'marquee cycle gate: timeout waiting for loop, continuing',
      );
    }
  }

  /// Call after curated rows are written; the next [awaitPriorMarqueePresentationIfAny]
  /// blocks until [notifyMarqueeLoopComplete] runs once (or [dispose]).
  void onCurationWrittenExpectMarqueeLoop() {
    _marqueeMustCompleteBeforeNextCuration = Completer<void>();
  }

  /// Called from [TickerMarquee] after one full horizontal loop, or immediately
  /// when there is nothing to animate.
  void notifyMarqueeLoopComplete() {
    final c = _marqueeMustCompleteBeforeNextCuration;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
  }

  /// Unblocks any waiter (e.g. app shutdown).
  void dispose() {
    notifyMarqueeLoopComplete();
    _marqueeMustCompleteBeforeNextCuration = null;
  }
}
