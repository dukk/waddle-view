import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:waddle_integrations/joke_jokeapi/jokeapi_http.dart';

void main() {
  test('buildJokeApiUri includes twopart amount blacklist and contains', () {
    final uri = buildJokeApiUri(
      baseUrl: 'https://v2.jokeapi.dev/joke',
      apiCategory: 'Programming',
      amount: 3,
      blacklistFlags: const ['nsfw', 'racist'],
      contains: 'C#',
    );
    expect(uri.path, endsWith('/Programming'));
    expect(uri.queryParameters['type'], 'twopart');
    expect(uri.queryParameters['amount'], '3');
    expect(uri.queryParameters['blacklistFlags'], 'nsfw,racist');
    expect(uri.queryParameters['contains'], 'C#');
  });

  test('normalizeJokeApiBaseUrl appends joke to legacy v2 base', () {
    expect(
      normalizeJokeApiBaseUrl('https://sv443.net/jokeapi/v2'),
      'https://sv443.net/jokeapi/v2/joke',
    );
  });

  test('jokeApiRateLimitUntilMsFromResponse uses Retry-After on 429', () {
    final res = http.Response('', 429, headers: {'retry-after': '30'});
    final until = jokeApiRateLimitUntilMsFromResponse(res, 1_000_000);
    expect(until, 1_030_000);
  });

  test('jokeApiRateLimitUntilMsFromResponse backs off when remaining is 0', () {
    final reset = HttpDate.format(
      DateTime.fromMillisecondsSinceEpoch(2_000_000),
    );
    final res = http.Response(
      '',
      200,
      headers: {
        'ratelimit-remaining': '0',
        'ratelimit-reset': reset,
      },
    );
    final until = jokeApiRateLimitUntilMsFromResponse(res, 1_000_000);
    expect(until, 2_000_000);
  });
}
