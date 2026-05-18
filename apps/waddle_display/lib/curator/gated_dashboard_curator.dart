import '../debug/app_debug_log.dart';
import '../marquee_cycle_gate.dart';
import 'curator_membership_filter.dart';
import 'dashboard_curator.dart';

/// Runs [inner] [DashboardCurator.refresh] only after the prior curated ticker
/// has completed one marquee presentation cycle ([MarqueeCycleGate]).
class GatedDashboardCurator implements DashboardCurator {
  GatedDashboardCurator({
    required DashboardCurator inner,
    required MarqueeCycleGate marqueeGate,
    CuratorMembershipFilter? membershipFilter,
  }) : _inner = inner,
       _marqueeGate = marqueeGate,
       _membershipFilter = membershipFilter;

  final DashboardCurator _inner;
  final MarqueeCycleGate _marqueeGate;
  final CuratorMembershipFilter? _membershipFilter;

  @override
  Future<void> refresh() async {
    if (_membershipFilter?.tickerCurationEnabled == false) {
      AppDebugLog.curator('ticker refresh (gated): skipped (disabled by curator)');
      await _inner.refresh();
      return;
    }
    AppDebugLog.curator('ticker refresh (gated): await prior marquee if any');
    await _marqueeGate.awaitPriorMarqueePresentationIfAny();
    await _inner.refresh();
    AppDebugLog.curator(
      'ticker refresh (gated): inner done, expect next marquee loop for gate',
    );
    _marqueeGate.onCurationWrittenExpectMarqueeLoop();
  }
}
