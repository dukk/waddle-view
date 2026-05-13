import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/data/providers/joke/joke_seasonal_eligibility.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('monthDayKey orders dates within a year', () {
    expect(monthDayKey(3, 5) < monthDayKey(3, 6), isTrue);
    expect(monthDayKey(12, 1) > monthDayKey(1, 6), isTrue);
  });

  test('same-calendar-year window', () {
    final d = DateTime(2026, 3, 10);
    expect(
      isDateInAnnualSeasonWindow(
        d,
        startMonth: 3,
        startDay: 1,
        endMonth: 3,
        endDay: 31,
      ),
      isTrue,
    );
    expect(
      isDateInAnnualSeasonWindow(
        DateTime(2026, 2, 28),
        startMonth: 3,
        startDay: 1,
        endMonth: 3,
        endDay: 31,
      ),
      isFalse,
    );
  });

  test('window wraps New Year (Dec 20 – Jan 5)', () {
    expect(
      isDateInAnnualSeasonWindow(
        DateTime(2026, 12, 25),
        startMonth: 12,
        startDay: 20,
        endMonth: 1,
        endDay: 5,
      ),
      isTrue,
    );
    expect(
      isDateInAnnualSeasonWindow(
        DateTime(2027, 1, 3),
        startMonth: 12,
        startDay: 20,
        endMonth: 1,
        endDay: 5,
      ),
      isTrue,
    );
    expect(
      isDateInAnnualSeasonWindow(
        DateTime(2026, 2, 1),
        startMonth: 12,
        startDay: 20,
        endMonth: 1,
        endDay: 5,
      ),
      isFalse,
    );
  });

  test('isJokeCategoryEligibleOn: non-seasonal always true', () {
    const row = JokeCategory(
      id: 'dad',
      label: 'Dad',
      isSeasonal: false,
      minJokes: 10,
      maxJokes: 100,
    );
    expect(
      isJokeCategoryEligibleOn(row, DateTime(2026, 7, 4)),
      isTrue,
    );
  });

  test('isJokeCategoryEligibleOn: seasonal uses window', () {
    final xmas = JokeCategory(
      id: 'x',
      label: 'X',
      isSeasonal: true,
      startMonth: 12,
      startDay: 1,
      endMonth: 1,
      endDay: 6,
      minJokes: 10,
      maxJokes: 100,
    );
    expect(isJokeCategoryEligibleOn(xmas, DateTime(2026, 12, 15)), isTrue);
    expect(isJokeCategoryEligibleOn(xmas, DateTime(2026, 7, 4)), isFalse);
  });

  test('isJokeCategoryEligibleOn: seasonal with null range is false', () {
    const row = JokeCategory(
      id: 'broken',
      label: 'B',
      isSeasonal: true,
      minJokes: 10,
      maxJokes: 100,
    );
    expect(isJokeCategoryEligibleOn(row, DateTime(2026, 7, 4)), isFalse);
  });
}
