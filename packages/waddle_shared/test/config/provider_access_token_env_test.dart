import 'package:test/test.dart';
import 'package:waddle_shared/config/provider_access_token_env.dart';

void main() {
  test('read token helpers trim and ignore empty values', () {
    const env = {
      waddleOpenAiApiKeyEnv: '  openai-key  ',
      waddleOpenWeatherMapApiKeyEnv: '',
      waddlePexelsApiKeyEnv: 'pexels',
      waddleFlickrApiKeyEnv: 'flickr',
      waddleFinhubApiKeyEnv: 'finnhub',
      waddleGoogleClientIdEnv: 'google-client',
      waddleMicrosoftGraphClientIdEnv: 'ms-client',
    };
    expect(readJokesTokenFromEnvMap(env), 'openai-key');
    expect(readWeatherTokenFromEnvMap(env), isNull);
    expect(readPexelsTokenFromEnvMap(env), 'pexels');
    expect(readFlickrTokenFromEnvMap(env), 'flickr');
    expect(readStocksTokenFromEnvMap(env), 'finnhub');
    expect(readGoogleClientIdFromEnvMap(env), 'google-client');
    expect(readMicrosoftGraphClientIdFromEnvMap(env), 'ms-client');
  });

  test('resolveProviderAccessTokenFromEnv maps provider aliases', () {
    const env = {waddleOpenAiApiKeyEnv: 'tok', waddlePexelsApiKeyEnv: 'pex'};
    expect(resolveProviderAccessTokenFromEnv('joke_openai', env), 'tok');
    expect(resolveProviderAccessTokenFromEnv('trivia_opentdb', env), 'tok');
    expect(resolveProviderAccessTokenFromEnv('photo_pexels', env), 'pex');
    expect(resolveProviderAccessTokenFromEnv('unknown_provider', env), isNull);
  });
}
