import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/joke/joke_slide_timing.dart';

void main() {
  test('punchlineDelayMs is half of dwell time', () {
    expect(punchlineDelayMs(10000), 5000);
    expect(punchlineDelayMs(9), 4);
    expect(punchlineDelayMs(8), 4);
  });

  test('punchlineDelayMs is zero for very short dwell', () {
    expect(punchlineDelayMs(0), 0);
    expect(punchlineDelayMs(1), 0);
  });
}
