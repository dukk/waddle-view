import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/data/providers/trivia/trivia_provider_extra_config.dart';

void main() {
  test('parse prefers maxQuestionPerDay and maxQuestionPerHour', () {
    final c = TriviaProviderExtraConfig.parse(
      '{"maxQuestionPerDay":10,"maxQuestionPerHour":7}',
    );
    expect(c.maxQuestionPerDay, 10);
    expect(c.maxQuestionPerHour, 7);
    expect(c.twoHourWindowMs, kDefaultTriviaRateWindowMs);
    expect(c.questionRetentionDays, kDefaultTriviaRetentionDays);
  });

  test('parse falls back to questionsPerDay and maxQuestionsPerTwoHours', () {
    final c = TriviaProviderExtraConfig.parse(
      '{"questionsPerDay":4,"maxQuestionsPerTwoHours":9}',
    );
    expect(c.maxQuestionPerDay, 4);
    expect(c.maxQuestionPerHour, 9);
  });

  test('empty config uses package defaults', () {
    final c = TriviaProviderExtraConfig.parse(null);
    expect(c.maxQuestionPerDay, kDefaultMaxQuestionPerDay);
    expect(c.maxQuestionPerHour, kDefaultMaxQuestionPerHour);
    expect(c.questionRetentionDays, kDefaultTriviaRetentionDays);
  });
}
