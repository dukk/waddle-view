import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/config/provider_access_token_env.dart';

void main() {
  test('readJokesTokenFromEnvMap', () {
    expect(
      readJokesTokenFromEnvMap({
        waddleOpenAiApiKeyEnv: '  a  ',
      }),
      'a',
    );
    expect(readJokesTokenFromEnvMap({}), isNull);
    expect(
      readJokesTokenFromEnvMap({waddleOpenAiApiKeyEnv: '  '}),
      isNull,
    );
  });

  test('readTriviaTokenFromEnvMap matches jokes resolution', () {
    expect(
      readTriviaTokenFromEnvMap({waddleOpenAiApiKeyEnv: 't'}),
      't',
    );
  });

  test('readWeatherTokenFromEnvMap', () {
    expect(
      readWeatherTokenFromEnvMap({waddleOpenWeatherMapApiKeyEnv: 'w'}),
      'w',
    );
    expect(readWeatherTokenFromEnvMap({}), isNull);
  });

  test('readPexelsTokenFromEnvMap', () {
    expect(
      readPexelsTokenFromEnvMap({waddlePexelsApiKeyEnv: 'p'}),
      'p',
    );
    expect(readPexelsTokenFromEnvMap({}), isNull);
  });

  test('readFlickrTokenFromEnvMap', () {
    expect(
      readFlickrTokenFromEnvMap({waddleFlickrApiKeyEnv: 'f'}),
      'f',
    );
    expect(readFlickrTokenFromEnvMap({}), isNull);
  });

  test('readStocksTokenFromEnvMap', () {
    expect(
      readStocksTokenFromEnvMap({waddleFinhubApiKeyEnv: 's'}),
      's',
    );
    expect(readStocksTokenFromEnvMap({}), isNull);
  });

  test('resolveProviderAccessTokenFromEnv known providers and null otherwise', () {
    expect(
      resolveProviderAccessTokenFromEnv('jokes', {
        waddleOpenAiApiKeyEnv: 'jk',
      }),
      'jk',
    );
    expect(
      resolveProviderAccessTokenFromEnv('trivia', {
        waddleOpenAiApiKeyEnv: 'tk',
      }),
      'tk',
    );
    expect(
      resolveProviderAccessTokenFromEnv('opentdb_trivia', {
        waddleOpenAiApiKeyEnv: 'ok',
      }),
      'ok',
    );
    expect(
      resolveProviderAccessTokenFromEnv('weather', {
        waddleOpenWeatherMapApiKeyEnv: 'wk',
      }),
      'wk',
    );
    expect(
      resolveProviderAccessTokenFromEnv('pexels', {waddlePexelsApiKeyEnv: 'pk'}),
      'pk',
    );
    expect(
      resolveProviderAccessTokenFromEnv('flickr_media', {
        waddleFlickrApiKeyEnv: 'fk',
      }),
      'fk',
    );
    expect(
      resolveProviderAccessTokenFromEnv('stocks', {waddleFinhubApiKeyEnv: 'sk'}),
      'sk',
    );
    expect(resolveProviderAccessTokenFromEnv('media_bing_iotd', {}), isNull);
    expect(
      resolveProviderAccessTokenFromEnv('weather_nws_alerts', {
        waddleOpenWeatherMapApiKeyEnv: 'ignored',
      }),
      isNull,
    );
    expect(
      resolveProviderAccessTokenFromEnv('unknown_provider', {
        waddleOpenAiApiKeyEnv: 'x',
      }),
      isNull,
    );
  });

  test('readJokesTokenFromEnvMap ignores blank explicit', () {
    expect(
      readJokesTokenFromEnvMap({
        waddleOpenAiApiKeyEnv: '   ',
      }),
      isNull,
    );
  });

  test('readTriviaTokenFromEnvMap ignores blank waddle OpenAI key', () {
    expect(
      readTriviaTokenFromEnvMap({
        waddleOpenAiApiKeyEnv: ' ',
      }),
      isNull,
    );
  });

  test('readPexelsTokenFromEnvMap ignores blank waddle key', () {
    expect(
      readPexelsTokenFromEnvMap({
        waddlePexelsApiKeyEnv: ' ',
      }),
      isNull,
    );
  });

  test('readFlickrTokenFromEnvMap ignores blank waddle key', () {
    expect(
      readFlickrTokenFromEnvMap({
        waddleFlickrApiKeyEnv: '\t',
      }),
      isNull,
    );
  });

  test('readStocksTokenFromEnvMap ignores blank waddle key', () {
    expect(
      readStocksTokenFromEnvMap({
        waddleFinhubApiKeyEnv: '',
      }),
      isNull,
    );
  });

}
