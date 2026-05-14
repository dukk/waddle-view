import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/config/dev_dotenv_secrets.dart';
import 'package:waddle_display/config/google_kv.dart';
import 'package:waddle_display/config/microsoft_graph_kv.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

void main() {
  test('readJokesTokenFromEnvMap prefers WADDLE_JOKES_ACCESS_TOKEN', () {
    expect(
      readJokesTokenFromEnvMap({
        waddleJokesAccessTokenKey: '  sk-waddle  ',
        openAiApiKeyEnv: 'sk-openai',
      }),
      'sk-waddle',
    );
  });

  test('readJokesTokenFromEnvMap falls back to OPENAI_API_KEY', () {
    expect(
      readJokesTokenFromEnvMap({openAiApiKeyEnv: 'sk-fallback'}),
      'sk-fallback',
    );
  });

  test('readJokesTokenFromEnvMap returns null when empty or missing', () {
    expect(readJokesTokenFromEnvMap({}), isNull);
    expect(
      readJokesTokenFromEnvMap({
        waddleJokesAccessTokenKey: '  ',
        openAiApiKeyEnv: '',
      }),
      isNull,
    );
  });

  test('readTriviaTokenFromEnvMap prefers WADDLE_TRIVIA_ACCESS_TOKEN', () {
    expect(
      readTriviaTokenFromEnvMap({
        waddleTriviaAccessTokenKey: ' sk-trivia ',
        waddleJokesAccessTokenKey: 'sk-jokes',
      }),
      'sk-trivia',
    );
  });

  test('readWeatherTokenFromEnvMap reads OPEN_WEATHER_MAP_API_KEY', () {
    expect(
      readWeatherTokenFromEnvMap({
        openWeatherMapApiKeyEnv: ' owm-token ',
      }),
      'owm-token',
    );
  });

  test('readPexelsTokenFromEnvMap prefers WADDLE_PEXELS_ACCESS_TOKEN', () {
    expect(
      readPexelsTokenFromEnvMap({
        waddlePexelsAccessTokenKey: ' pex-a ',
        pexelsApiKeyEnv: 'pex-b',
      }),
      'pex-a',
    );
  });

  test('readPexelsTokenFromEnvMap falls back to PEXELS_API_KEY', () {
    expect(
      readPexelsTokenFromEnvMap({pexelsApiKeyEnv: ' pex-only '}),
      'pex-only',
    );
  });

  test('readFlickrTokenFromEnvMap prefers WADDLE_FLICKR_ACCESS_TOKEN', () {
    expect(
      readFlickrTokenFromEnvMap({
        waddleFlickrAccessTokenKey: ' fl-a ',
        flickrApiKeyEnv: 'fl-b',
      }),
      'fl-a',
    );
  });

  test('readFlickrTokenFromEnvMap falls back to FLICKR_API_KEY', () {
    expect(
      readFlickrTokenFromEnvMap({flickrApiKeyEnv: ' fl-only '}),
      'fl-only',
    );
  });

  test('readStocksTokenFromEnvMap reads FINNHUB_API_KEY', () {
    expect(
      readStocksTokenFromEnvMap({finnhubApiKeyEnv: ' fhub-token '}),
      'fhub-token',
    );
  });

  test('readStocksTokenFromEnvMap prefers WADDLE_STOCKS_ACCESS_TOKEN', () {
    expect(
      readStocksTokenFromEnvMap({
        waddleStocksAccessTokenKey: ' waddle-stocks ',
        finnhubApiKeyEnv: 'fhub',
      }),
      'waddle-stocks',
    );
  });

  test('readStocksTokenFromEnvMap returns null when empty', () {
    expect(readStocksTokenFromEnvMap({}), isNull);
    expect(
      readStocksTokenFromEnvMap({
        waddleStocksAccessTokenKey: '   ',
        finnhubApiKeyEnv: '',
      }),
      isNull,
    );
  });

  test('applyMicrosoftGraphTokensFromDevDotenv writes access and refresh', () async {
    dotenv.clean();
    dotenv.loadFromString(
      envString:
          '${waddleMsGraphAccessTokenPrefix}work=acc123\n'
          '${waddleMsGraphRefreshTokenPrefix}work=ref456',
      isOptional: true,
    );
    final secrets = InMemorySecretStore();
    await applyMicrosoftGraphTokensFromDevDotenv(secrets);
    expect(await secrets.read(microsoftGraphAccessTokenSecret('work')), 'acc123');
    expect(await secrets.read(microsoftGraphRefreshTokenSecret('work')), 'ref456');
  });

  test('applyGoogleTokensFromDevDotenv writes access and refresh', () async {
    dotenv.clean();
    dotenv.loadFromString(
      envString:
          '${waddleGoogleAccessTokenPrefix}home=acc123\n'
          '${waddleGoogleRefreshTokenPrefix}home=ref456',
      isOptional: true,
    );
    final secrets = InMemorySecretStore();
    await applyGoogleTokensFromDevDotenv(secrets);
    expect(await secrets.read(googleAccessTokenSecret('home')), 'acc123');
    expect(await secrets.read(googleRefreshTokenSecret('home')), 'ref456');
  });
}
