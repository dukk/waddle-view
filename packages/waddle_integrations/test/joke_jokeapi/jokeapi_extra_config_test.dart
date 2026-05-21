import 'package:test/test.dart';
import 'package:waddle_integrations/joke_jokeapi/jokeapi_extra_config.dart';

void main() {
  test('parse uses defaults for empty config', () {
    final c = JokeApiExtraConfig.parse(null);
    expect(c.jokesPerPoll, kDefaultJokeApiJokesPerPoll);
    expect(c.jokeRetentionDays, kDefaultJokeApiRetentionDays);
    expect(c.categoryMap, isEmpty);
    expect(c.blacklistFlags, isEmpty);
    expect(c.contains, isNull);
  });

  test('parse reads valid fields and clamps jokesPerPoll', () {
    final c = JokeApiExtraConfig.parse(
      '{"jokesPerPoll":99,"contains":"  dev  ",'
      '"blacklistFlags":["nsfw","invalid","racist","nsfw"],'
      '"categoryMap":{"general":"Misc","tech":"Programming"},'
      '"jokeRetentionDays":7}',
    );
    expect(c.jokesPerPoll, 10);
    expect(c.contains, 'dev');
    expect(c.blacklistFlags, ['nsfw', 'racist']);
    expect(c.categoryMap['general'], 'Misc');
    expect(c.categoryMap['tech'], 'Programming');
    expect(c.jokeRetentionDays, 7);
  });

  test('parse clamps jokesPerPoll minimum to 1', () {
    final c = JokeApiExtraConfig.parse('{"jokesPerPoll":0}');
    expect(c.jokesPerPoll, 1);
  });
}
