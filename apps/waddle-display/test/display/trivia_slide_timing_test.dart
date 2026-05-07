import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/dashboard/trivia_slide_timing.dart';

void main() {
  test('elimination window prefers larger of scaled and reserved dwell', () {
    expect(triviaEliminationWindowMs(10000), 8500);
    expect(triviaEliminationWindowMs(2000), 1500);
  });

  test('config override wins when positive', () {
    expect(
      triviaEliminationWindowMs(10000, configOverride: 3000),
      3000,
    );
  });

  test('elimination end includes last strike animation duration', () {
    expect(triviaEliminationEndMs(8000), 3 * 2000 + kTriviaStrikeAnimationMs);
    expect(triviaEliminationEndMs(3), greaterThan(3));
  });
}
