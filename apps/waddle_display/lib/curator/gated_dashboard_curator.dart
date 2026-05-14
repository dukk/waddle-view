import '../debug/app_debug_log.dart';
import '../marquee_cycle_gate.dart';
import 'dashboard_curator.dart';

/// Runs [inner] [DashboardCurator.refresh] only after the prior curated ticker
/// has completed one marquee presentation cycle ([MarqueeCycleGate]).
class GatedDashboardCurator implements DashboardCurator {
  GatedDashboardCurator({
    required DashboardCurator inner,
    required MarqueeCycleGate marqueeGate,
  }) : _inner = inner,
       _marqueeGate = marqueeGate;

  final DashboardCurator _inner;
  final MarqueeCycleGate _marqueeGate;

  @override
  Future<void> refresh() async {
    AppDebugLog.curator('ticker refresh (gated): await prior marquee if any');
    await _marqueeGate.awaitPriorMarqueePresentationIfAny();
    await _inner.refresh();
    AppDebugLog.curator(
      'ticker refresh (gated): inner done, expect next marquee loop for gate',
    );
    _marqueeGate.onCurationWrittenExpectMarqueeLoop();
  }
}
