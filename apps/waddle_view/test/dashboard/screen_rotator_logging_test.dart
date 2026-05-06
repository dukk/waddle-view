import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/dashboard/screen_rotator.dart';

void main() {
  test('screenShownDebugLogLine includes definition and context', () {
    final line = screenShownDebugLogLine(
      reason: 'initial',
      slideIndex: 2,
      totalSlides: 5,
      screenId: 'analog_clock',
      dwellMs: 30000,
      layoutJson: '{"v":1,"widgets":[{"type":"analog_clock"}]}',
      randomChoices: {'main_photo_random': 'blob-1'},
    );

    expect(line, contains('screen shown: reason=initial'));
    expect(line, contains('index=2/5'));
    expect(line, contains('screenId=analog_clock'));
    expect(line, contains('dwellMs=30000'));
    expect(line, contains('layout={"v":1,"widgets":[{"type":"analog_clock"}]}'));
    expect(line, contains('randomChoices={main_photo_random: blob-1}'));
  });

}
