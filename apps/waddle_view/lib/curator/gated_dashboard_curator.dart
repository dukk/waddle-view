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
    await _marqueeGate.awaitPriorMarqueePresentationIfAny();
    await _inner.refresh();
    _marqueeGate.onCurationWrittenExpectMarqueeLoop();
  }
}
