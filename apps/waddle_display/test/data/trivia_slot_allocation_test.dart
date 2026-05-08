import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/data/providers/trivia/trivia_slot_allocation.dart';
import 'package:waddle_display/persistence/database.dart';

void main() {
  test('returns empty when budget is zero or no categories', () {
    final dad = const TriviaCategory(
      id: 'dad',
      label: 'Dad',
      isSeasonal: false,
      minQuestions: 10,
      maxQuestions: 100,
    );
    expect(
      buildTriviaRequestSlots(
        eligibleSorted: [dad],
        storedByCategoryId: {},
        budget: 0,
        roundRobinStartIndex: 0,
      ),
      isEmpty,
    );
    expect(
      buildTriviaRequestSlots(
        eligibleSorted: [],
        storedByCategoryId: {},
        budget: 3,
        roundRobinStartIndex: 0,
      ),
      isEmpty,
    );
  });

  test('round-robin fills slots with start index zero', () {
    final dad = const TriviaCategory(
      id: 'dad',
      label: 'Dad',
      isSeasonal: false,
      minQuestions: 10,
      maxQuestions: 100,
    );
    final mom = const TriviaCategory(
      id: 'mom',
      label: 'Mom',
      isSeasonal: false,
      minQuestions: 10,
      maxQuestions: 100,
    );
    final slots = buildTriviaRequestSlots(
      eligibleSorted: [dad, mom],
      storedByCategoryId: {'dad': 0, 'mom': 0},
      budget: 3,
      roundRobinStartIndex: 0,
    );
    expect(slots.map((s) => s.id).toList(), ['dad', 'mom', 'dad']);
  });

  test('round-robin rotates order when start index is one', () {
    final dad = const TriviaCategory(
      id: 'dad',
      label: 'Dad',
      isSeasonal: false,
      minQuestions: 10,
      maxQuestions: 100,
    );
    final mom = const TriviaCategory(
      id: 'mom',
      label: 'Mom',
      isSeasonal: false,
      minQuestions: 10,
      maxQuestions: 100,
    );
    final slots = buildTriviaRequestSlots(
      eligibleSorted: [dad, mom],
      storedByCategoryId: {'dad': 0, 'mom': 0},
      budget: 3,
      roundRobinStartIndex: 1,
    );
    expect(slots.map((s) => s.id).toList(), ['mom', 'dad', 'mom']);
  });

  test('skips categories at max question inventory', () {
    final dad = const TriviaCategory(
      id: 'dad',
      label: 'Dad',
      isSeasonal: false,
      minQuestions: 1,
      maxQuestions: 5,
    );
    final mom = const TriviaCategory(
      id: 'mom',
      label: 'Mom',
      isSeasonal: false,
      minQuestions: 10,
      maxQuestions: 100,
    );
    final slots = buildTriviaRequestSlots(
      eligibleSorted: [dad, mom],
      storedByCategoryId: {'dad': 5, 'mom': 0},
      budget: 5,
      roundRobinStartIndex: 0,
    );
    expect(slots.every((s) => s.id == 'mom'), isTrue);
    expect(slots.length, 5);
  });
}
