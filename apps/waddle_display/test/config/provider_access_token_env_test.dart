import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/config/provider_access_token_env.dart';

void main() {
  test('waddleProviderAccessTokenEnvKey upper-snakes provider id', () {
    expect(
      waddleProviderAccessTokenEnvKey('opentdb_trivia'),
      'WADDLE_PROVIDER_ACCESS_TOKEN_OPENTDB_TRIVIA',
    );
    expect(
      waddleProviderAccessTokenEnvKey('bing-image-of-day'),
      'WADDLE_PROVIDER_ACCESS_TOKEN_BING_IMAGE_OF_DAY',
    );
  });

  test('readJokesTokenFromEnvMap', () {
    expect(
      readJokesTokenFromEnvMap({
        waddleJokesAccessTokenKey: '  a  ',
        openAiApiKeyEnv: 'b',
      }),
      'a',
    );
    expect(readJokesTokenFromEnvMap({openAiApiKeyEnv: 'x'}), 'x');
    expect(readJokesTokenFromEnvMap({}), isNull);
    expect(readJokesTokenFromEnvMap({openAiApiKeyEnv: '  '}), isNull);
  });

  test('readTriviaTokenFromEnvMap', () {
    expect(
      readTriviaTokenFromEnvMap({waddleTriviaAccessTokenKey: 't'}),
      't',
    );
    expect(readTriviaTokenFromEnvMap({openAiApiKeyEnv: 'j'}), 'j');
  });

  test('readWeatherTokenFromEnvMap', () {
    expect(
      readWeatherTokenFromEnvMap({openWeatherMapApiKeyEnv: 'w'}),
      'w',
    );
    expect(readWeatherTokenFromEnvMap({}), isNull);
  });

  test('readPexelsTokenFromEnvMap', () {
    expect(
      readPexelsTokenFromEnvMap({waddlePexelsAccessTokenKey: 'p'}),
      'p',
    );
    expect(readPexelsTokenFromEnvMap({pexelsApiKeyEnv: 'q'}), 'q');
  });

  test('readFlickrTokenFromEnvMap', () {
    expect(
      readFlickrTokenFromEnvMap({waddleFlickrAccessTokenKey: 'f'}),
      'f',
    );
    expect(readFlickrTokenFromEnvMap({flickrApiKeyEnv: 'g'}), 'g');
  });

  test('readStocksTokenFromEnvMap', () {
    expect(
      readStocksTokenFromEnvMap({waddleStocksAccessTokenKey: 's'}),
      's',
    );
    expect(readStocksTokenFromEnvMap({finnhubApiKeyEnv: 't'}), 't');
  });

  test('resolveProviderAccessTokenFromEnv switch and default', () {
    expect(
      resolveProviderAccessTokenFromEnv('jokes', {
        openAiApiKeyEnv: 'jk',
      }),
      'jk',
    );
    expect(
      resolveProviderAccessTokenFromEnv('trivia', {
        waddleTriviaAccessTokenKey: 'tk',
      }),
      'tk',
    );
    expect(
      resolveProviderAccessTokenFromEnv('opentdb_trivia', {
        openAiApiKeyEnv: 'ok',
      }),
      'ok',
    );
    expect(
      resolveProviderAccessTokenFromEnv('weather', {
        openWeatherMapApiKeyEnv: 'wk',
      }),
      'wk',
    );
    expect(
      resolveProviderAccessTokenFromEnv('pexels', {pexelsApiKeyEnv: 'pk'}),
      'pk',
    );
    expect(
      resolveProviderAccessTokenFromEnv('flickr_media', {
        flickrApiKeyEnv: 'fk',
      }),
      'fk',
    );
    expect(
      resolveProviderAccessTokenFromEnv('stocks', {finnhubApiKeyEnv: 'sk'}),
      'sk',
    );
    expect(
      resolveProviderAccessTokenFromEnv('bing_image_of_day', {
        'WADDLE_PROVIDER_ACCESS_TOKEN_BING_IMAGE_OF_DAY': 'bk',
      }),
      'bk',
    );
    expect(resolveProviderAccessTokenFromEnv('bing_image_of_day', {}), isNull);
  });

  test('readJokesTokenFromEnvMap ignores blank explicit', () {
    expect(
      readJokesTokenFromEnvMap({
        waddleJokesAccessTokenKey: '   ',
        openAiApiKeyEnv: 'ok',
      }),
      'ok',
    );
  });

  test('readTriviaTokenFromEnvMap ignores blank explicit trivia key', () {
    expect(
      readTriviaTokenFromEnvMap({
        waddleTriviaAccessTokenKey: ' ',
        openAiApiKeyEnv: 'x',
      }),
      'x',
    );
  });

  test('readPexelsTokenFromEnvMap ignores blank waddle key', () {
    expect(
      readPexelsTokenFromEnvMap({
        waddlePexelsAccessTokenKey: ' ',
        pexelsApiKeyEnv: 'p',
      }),
      'p',
    );
  });

  test('readFlickrTokenFromEnvMap ignores blank waddle key', () {
    expect(
      readFlickrTokenFromEnvMap({
        waddleFlickrAccessTokenKey: '\t',
        flickrApiKeyEnv: 'f',
      }),
      'f',
    );
  });

  test('readStocksTokenFromEnvMap ignores blank waddle key', () {
    expect(
      readStocksTokenFromEnvMap({
        waddleStocksAccessTokenKey: '',
        finnhubApiKeyEnv: 's',
      }),
      's',
    );
  });

  test('resolveProviderAccessTokenFromEnv default trims generic key', () {
    expect(
      resolveProviderAccessTokenFromEnv('nws_weather_alerts', {
        'WADDLE_PROVIDER_ACCESS_TOKEN_NWS_WEATHER_ALERTS': '  ua  ',
      }),
      'ua',
    );
    expect(
      resolveProviderAccessTokenFromEnv('nws_weather_alerts', {
        'WADDLE_PROVIDER_ACCESS_TOKEN_NWS_WEATHER_ALERTS': ' ',
      }),
      isNull,
    );
  });
}
