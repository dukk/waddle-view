import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/pexels/pexels_video_playback_gate.dart';

void main() {
  tearDown(PexelsVideoPlaybackGate.instance.resetForTest);

  test('run serializes overlapping work', () async {
    final gate = PexelsVideoPlaybackGate.instance;
    final log = <int>[];

    final first = gate.run(() async {
      log.add(1);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      log.add(2);
    });
    final second = gate.run(() async {
      log.add(3);
    });

    await Future.wait([first, second]);
    expect(log, [1, 2, 3]);
  });
}
