import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_data_providers/trivia_openai/trivia_id.dart';

void main() {
  test('multiple_choice id matches legacy null option payload', () {
    final id = triviaStableId(
      'cat',
      'Q?',
      'A',
      'B',
      null,
      null,
      'A',
    );
    expect(
      id,
      triviaStableId(
        'cat',
        'Q?',
        'A',
        'B',
        null,
        null,
        'A',
        kTriviaQuestionTypeMultipleChoice,
      ),
    );
  });

  test('true_false uses distinct payload from multiple_choice', () {
    final mc = triviaStableId(
      'cat',
      'Q?',
      'A',
      'B',
      null,
      null,
      'A',
      kTriviaQuestionTypeMultipleChoice,
    );
    final tf = triviaStableId(
      'cat',
      'Q?',
      'A',
      'B',
      null,
      null,
      'A',
      kTriviaQuestionTypeTrueFalse,
    );
    expect(mc, isNot(tf));
  });
}
