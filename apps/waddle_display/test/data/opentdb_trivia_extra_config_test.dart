import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_data_providers/trivia_opentdb/opentdb_trivia_extra_config.dart';

void main() {
  test('parse uses defaults for empty config', () {
    final c = OpenTdbTriviaExtraConfig.parse(null);
    expect(c.amount, kDefaultOpenTdbAmount);
    expect(c.questionRetentionDays, kDefaultOpenTdbRetentionDays);
    expect(c.questionType, isNull);
  });

  test('parse reads valid fields', () {
    final c = OpenTdbTriviaExtraConfig.parse(
      '{"amount":7,"difficulty":"hard","questionType":"boolean",'
      '"categoryMap":{"science":17},"questionRetentionDays":20}',
    );
    expect(c.amount, 7);
    expect(c.difficulty, 'hard');
    expect(c.questionType, 'boolean');
    expect(c.categoryMap['science'], 17);
    expect(c.questionRetentionDays, 20);
  });
}
