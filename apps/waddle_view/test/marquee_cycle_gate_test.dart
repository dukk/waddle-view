import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/marquee_cycle_gate.dart';

void main() {
  test('awaitPrior is no-op when nothing armed', () async {
    final gate = MarqueeCycleGate();
    await gate.awaitPriorMarqueePresentationIfAny();
    gate.dispose();
  });

  test('notify completes armed gate so awaitPrior returns', () async {
    final gate = MarqueeCycleGate();
    gate.onCurationWrittenExpectMarqueeLoop();
    final waiter = gate.awaitPriorMarqueePresentationIfAny();
    await Future<void>.delayed(Duration.zero);
    gate.notifyMarqueeLoopComplete();
    await waiter;
    gate.dispose();
  });

  test('dispose completes waiter', () async {
    final gate = MarqueeCycleGate();
    gate.onCurationWrittenExpectMarqueeLoop();
    gate.dispose();
    await gate.awaitPriorMarqueePresentationIfAny();
  });

  test('awaitPrior returns after timeout when loop never notified', () async {
    final gate = MarqueeCycleGate(
      presentationWaitTimeout: const Duration(milliseconds: 20),
    );
    gate.onCurationWrittenExpectMarqueeLoop();
    await gate.awaitPriorMarqueePresentationIfAny();
    gate.dispose();
  });
}
