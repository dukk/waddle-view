import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/trivia/trivia_slide_timing.dart';
import 'package:waddle_display/display/screens/trivia/trivia_strike_animation.dart';

void main() {
  test('parseTriviaStrikeAnimationKind accepts aliases', () {
    expect(
      parseTriviaStrikeAnimationKind({'strikeAnimation': 'hand_drawn_x'}),
      TriviaStrikeAnimationKind.handDrawnX,
    );
    expect(
      parseTriviaStrikeAnimationKind({'strikeAnimation': 'STRIKE-OUT-X'}),
      TriviaStrikeAnimationKind.strikeOutX,
    );
    expect(
      parseTriviaStrikeAnimationKind({'strikeAnimation': 'scribble'}),
      TriviaStrikeAnimationKind.scribbleOut,
    );
    expect(
      parseTriviaStrikeAnimationKind({'strikeAnimation': 'fade_out'}),
      TriviaStrikeAnimationKind.fadeOut,
    );
    expect(
      parseTriviaStrikeAnimationKind({'strikeAnimation': 'TRANSPARENT'}),
      TriviaStrikeAnimationKind.fadeOut,
    );
    expect(
      parseTriviaStrikeAnimationKind({'strikeAnimation': 'unknown'}),
      TriviaStrikeAnimationKind.scribbleOut,
    );
    expect(
      parseTriviaStrikeAnimationKind({}),
      TriviaStrikeAnimationKind.scribbleOut,
    );
  });

  test('parseStrikeAnimationDurationMs clamps and defaults', () {
    expect(parseStrikeAnimationDurationMs({}), kTriviaStrikeAnimationMs);
    expect(parseStrikeAnimationDurationMs({'strikeAnimationDurationMs': 50}), 120);
    expect(parseStrikeAnimationDurationMs({'strikeAnimationDurationMs': 450}), 450);
    expect(parseStrikeAnimationDurationMs({'strikeAnimationDurationMs': 99999}), 3000);
  });

  test('elimination end uses parsed strike duration', () {
    final ms = parseStrikeAnimationDurationMs({'strikeAnimationDurationMs': 900});
    expect(
      triviaEliminationEndMs(8000, strikeAnimationMs: ms),
      3 * 2000 + 900,
    );
  });
}
