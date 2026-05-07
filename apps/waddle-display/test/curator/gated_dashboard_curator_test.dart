import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/curator/dashboard_curator.dart';
import 'package:waddle_view/curator/gated_dashboard_curator.dart';
import 'package:waddle_view/marquee_cycle_gate.dart';

class _RecordingCurator implements DashboardCurator {
  _RecordingCurator();

  final List<String> log = <String>[];

  @override
  Future<void> refresh() async {
    log.add('refresh');
  }
}

void main() {
  test('first refresh runs inner immediately then arms gate', () async {
    final gate = MarqueeCycleGate();
    final inner = _RecordingCurator();
    final gated = GatedDashboardCurator(inner: inner, marqueeGate: gate);
    await gated.refresh();
    expect(inner.log, <String>['refresh']);
    final waiter = gate.awaitPriorMarqueePresentationIfAny();
    var completed = false;
    waiter.then((_) {
      completed = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    gate.notifyMarqueeLoopComplete();
    await waiter;
    expect(completed, isTrue);
    gate.dispose();
  });

  test('second refresh waits for marquee notify after first', () async {
    final gate = MarqueeCycleGate();
    final inner = _RecordingCurator();
    final gated = GatedDashboardCurator(inner: inner, marqueeGate: gate);
    await gated.refresh();
    expect(inner.log, <String>['refresh']);
    final second = gated.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(inner.log, <String>['refresh']);
    gate.notifyMarqueeLoopComplete();
    await second;
    expect(inner.log, <String>['refresh', 'refresh']);
    gate.dispose();
  });
}
