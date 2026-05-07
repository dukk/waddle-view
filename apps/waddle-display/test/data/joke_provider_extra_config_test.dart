import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/data/providers/joke/joke_provider_extra_config.dart';

void main() {
  test('parse reads rolling window and 2h cap', () {
    final c = JokeProviderExtraConfig.parse(
      '{"maxJokesPerTwoHours":15,"twoHourWindowMs":3600000}',
    );
    expect(c.maxJokesPerTwoHours, 15);
    expect(c.twoHourWindowMs, 3600000);
  });

  test('defaults when extra empty', () {
    final c = JokeProviderExtraConfig.parse(null);
    expect(c.maxJokesPerTwoHours, kDefaultMaxJokesPerTwoHours);
    expect(c.twoHourWindowMs, kDefaultTwoHourWindowMs);
    expect(c.jokeRetentionDays, kDefaultJokeRetentionDays);
  });
}
