import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/data/providers/joke/joke_slot_allocation.dart';
import 'package:waddle_display/persistence/database.dart';

void main() {
  test('returns empty when budget is zero or no categories', () {
    final dad = const JokeCategory(
      id: 'dad',
      label: 'Dad',
      isSeasonal: false,
      minJokes: 10,
      maxJokes: 100,
    );
    expect(
      buildJokeRequestSlots(
        eligibleSorted: [dad],
        storedByCategoryId: {},
        budget: 0,
      ),
      isEmpty,
    );
    expect(
      buildJokeRequestSlots(
        eligibleSorted: [],
        storedByCategoryId: {},
        budget: 3,
      ),
      isEmpty,
    );
  });

  test('prioritizes deficit toward minimum before round-robin growth', () {
    final dad = const JokeCategory(
      id: 'dad',
      label: 'Dad',
      isSeasonal: false,
      minJokes: 10,
      maxJokes: 100,
    );
    final mom = const JokeCategory(
      id: 'mom',
      label: 'Mom',
      isSeasonal: false,
      minJokes: 10,
      maxJokes: 100,
    );
    final slots = buildJokeRequestSlots(
      eligibleSorted: [dad, mom],
      storedByCategoryId: {'dad': 0, 'mom': 0},
      budget: 3,
    );
    expect(slots.map((s) => s.id).toList(), ['dad', 'mom', 'dad']);
  });

  test('skips categories at max joke inventory', () {
    final dad = const JokeCategory(
      id: 'dad',
      label: 'Dad',
      isSeasonal: false,
      minJokes: 1,
      maxJokes: 5,
    );
    final mom = const JokeCategory(
      id: 'mom',
      label: 'Mom',
      isSeasonal: false,
      minJokes: 10,
      maxJokes: 100,
    );
    final slots = buildJokeRequestSlots(
      eligibleSorted: [dad, mom],
      storedByCategoryId: {'dad': 5, 'mom': 0},
      budget: 5,
    );
    expect(slots.every((s) => s.id == 'mom'), isTrue);
    expect(slots.length, 5);
  });
}
