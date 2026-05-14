import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/trivia/trivia_correct_reveal_animation.dart';

void main() {
  test('parseTriviaCorrectRevealKind accepts aliases', () {
    expect(
      parseTriviaCorrectRevealKind({'correctRevealAnimation': 'wobbly_ring'}),
      TriviaCorrectRevealKind.wobblyRing,
    );
    expect(
      parseTriviaCorrectRevealKind({'correctRevealAnimation': 'DOUBLE-SWEEP'}),
      TriviaCorrectRevealKind.doubleSweep,
    );
    expect(
      parseTriviaCorrectRevealKind({'correctRevealAnimation': 'smooth'}),
      TriviaCorrectRevealKind.smoothRing,
    );
    expect(
      parseTriviaCorrectRevealKind({'correctRevealAnimation': 'unknown'}),
      TriviaCorrectRevealKind.smoothRing,
    );
    expect(parseTriviaCorrectRevealKind({}), TriviaCorrectRevealKind.smoothRing);
  });

  test('parseCorrectRevealAnimationDurationMs clamps and defaults', () {
    expect(parseCorrectRevealAnimationDurationMs({}), kTriviaCorrectRevealAnimationMs);
    expect(
      parseCorrectRevealAnimationDurationMs({
        'correctRevealAnimationDurationMs': 50,
      }),
      120,
    );
    expect(
      parseCorrectRevealAnimationDurationMs({
        'correctRevealAnimationDurationMs': 450,
      }),
      450,
    );
    expect(
      parseCorrectRevealAnimationDurationMs({
        'correctRevealAnimationDurationMs': 99999,
      }),
      3000,
    );
  });
}
