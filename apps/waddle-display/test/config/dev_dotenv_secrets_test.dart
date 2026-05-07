import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/config/dev_dotenv_secrets.dart';
import 'package:waddle_display/config/google_kv.dart';
import 'package:waddle_display/config/microsoft_graph_kv.dart';
import 'package:waddle_display/config/provider_config_resolver.dart';
import 'package:waddle_display/secrets/in_memory_secret_store.dart';

void main() {
  test('readJokesTokenFromDotenvMap prefers WADDLE_JOKES_ACCESS_TOKEN', () {
    expect(
      readJokesTokenFromDotenvMap({
        waddleJokesAccessTokenKey: '  sk-waddle  ',
        openAiApiKeyEnv: 'sk-openai',
      }),
      'sk-waddle',
    );
  });

  test('readJokesTokenFromDotenvMap falls back to OPENAI_API_KEY', () {
    expect(
      readJokesTokenFromDotenvMap({openAiApiKeyEnv: 'sk-fallback'}),
      'sk-fallback',
    );
  });

  test('readJokesTokenFromDotenvMap returns null when empty or missing', () {
    expect(readJokesTokenFromDotenvMap({}), isNull);
    expect(
      readJokesTokenFromDotenvMap({
        waddleJokesAccessTokenKey: '  ',
        openAiApiKeyEnv: '',
      }),
      isNull,
    );
  });

  test('applyJokesTokenFromDevDotenv writes OPENAI_API_KEY to SecretStore', () async {
    dotenv.clean();
    dotenv.loadFromString(
      envString: 'OPENAI_API_KEY=sk-from-dotenv',
      isOptional: true,
    );
    final secrets = InMemorySecretStore();
    await applyJokesTokenFromDevDotenv(secrets);
    expect(
      await secrets.read('provider:access_token:jokes'),
      'sk-from-dotenv',
    );
    expect(
      await secrets.read('provider:access_token:trivia'),
      'sk-from-dotenv',
    );
  });

  test('applyJokesTokenFromDevDotenv prefers WADDLE_JOKES_ACCESS_TOKEN', () async {
    dotenv.clean();
    dotenv.loadFromString(
      envString:
          'OPENAI_API_KEY=sk-openai\nWADDLE_JOKES_ACCESS_TOKEN=sk-waddle\n',
      isOptional: true,
    );
    final secrets = InMemorySecretStore();
    await applyJokesTokenFromDevDotenv(secrets);
    expect(await secrets.read('provider:access_token:jokes'), 'sk-waddle');
    expect(await secrets.read('provider:access_token:trivia'), 'sk-waddle');
  });

  test('readTriviaTokenFromDotenvMap prefers WADDLE_TRIVIA_ACCESS_TOKEN', () {
    expect(
      readTriviaTokenFromDotenvMap({
        waddleTriviaAccessTokenKey: ' sk-trivia ',
        waddleJokesAccessTokenKey: 'sk-jokes',
      }),
      'sk-trivia',
    );
  });

  test('applyJokesTokenFromDevDotenv uses trivia-specific token when set', () async {
    dotenv.clean();
    dotenv.loadFromString(
      envString:
          'OPENAI_API_KEY=sk-openai\nWADDLE_TRIVIA_ACCESS_TOKEN=sk-trivia-only\n',
      isOptional: true,
    );
    final secrets = InMemorySecretStore();
    await applyJokesTokenFromDevDotenv(secrets);
    expect(await secrets.read('provider:access_token:jokes'), 'sk-openai');
    expect(await secrets.read('provider:access_token:trivia'), 'sk-trivia-only');
  });

  test('applyJokesTokenFromDevDotenv no-op when env has no token keys', () async {
    dotenv.clean();
    dotenv.loadFromString(envString: 'FOO=bar', isOptional: true);
    final secrets = InMemorySecretStore();
    await applyJokesTokenFromDevDotenv(secrets);
    expect(await secrets.read('provider:access_token:jokes'), isNull);
    expect(await secrets.read('provider:access_token:trivia'), isNull);
    expect(await secrets.read('provider:access_token:weather'), isNull);
  });

  test('readWeatherTokenFromDotenvMap reads OPEN_WEATHER_MAP_API_KEY', () {
    expect(
      readWeatherTokenFromDotenvMap({
        openWeatherMapApiKeyEnv: ' owm-token ',
      }),
      'owm-token',
    );
  });

  test('applyJokesTokenFromDevDotenv writes OPEN_WEATHER_MAP_API_KEY', () async {
    dotenv.clean();
    dotenv.loadFromString(
      envString: 'OPEN_WEATHER_MAP_API_KEY=owm-from-dotenv',
      isOptional: true,
    );
    final secrets = InMemorySecretStore();
    await applyJokesTokenFromDevDotenv(secrets);
    expect(
      await secrets.read('provider:access_token:weather'),
      'owm-from-dotenv',
    );
  });

  test('readPexelsTokenFromDotenvMap prefers WADDLE_PEXELS_ACCESS_TOKEN', () {
    expect(
      readPexelsTokenFromDotenvMap({
        waddlePexelsAccessTokenKey: ' pex-a ',
        pexelsApiKeyEnv: 'pex-b',
      }),
      'pex-a',
    );
  });

  test('readPexelsTokenFromDotenvMap falls back to PEXELS_API_KEY', () {
    expect(
      readPexelsTokenFromDotenvMap({pexelsApiKeyEnv: ' pex-only '}),
      'pex-only',
    );
  });

  test('applyJokesTokenFromDevDotenv writes Pexels key', () async {
    dotenv.clean();
    dotenv.loadFromString(
      envString: 'PEXELS_API_KEY=pex-from-dotenv',
      isOptional: true,
    );
    final secrets = InMemorySecretStore();
    await applyJokesTokenFromDevDotenv(secrets);
    expect(
      await secrets.read('${ProviderConfigResolver.accessTokenKey}:pexels'),
      'pex-from-dotenv',
    );
  });

  test('readStocksTokenFromDotenvMap reads FINNHUB_API_KEY', () {
    expect(
      readStocksTokenFromDotenvMap({finnhubApiKeyEnv: ' fhub-token '}),
      'fhub-token',
    );
  });

  test('readStocksTokenFromDotenvMap prefers WADDLE_STOCKS_ACCESS_TOKEN', () {
    expect(
      readStocksTokenFromDotenvMap({
        waddleStocksAccessTokenKey: ' waddle-stocks ',
        finnhubApiKeyEnv: 'fhub',
      }),
      'waddle-stocks',
    );
  });

  test('readStocksTokenFromDotenvMap returns null when empty', () {
    expect(readStocksTokenFromDotenvMap({}), isNull);
    expect(
      readStocksTokenFromDotenvMap({
        waddleStocksAccessTokenKey: '   ',
        finnhubApiKeyEnv: '',
      }),
      isNull,
    );
  });

  test('applyJokesTokenFromDevDotenv writes FINNHUB_API_KEY', () async {
    dotenv.clean();
    dotenv.loadFromString(
      envString: 'FINNHUB_API_KEY=fhub-from-dotenv',
      isOptional: true,
    );
    final secrets = InMemorySecretStore();
    await applyJokesTokenFromDevDotenv(secrets);
    expect(
      await secrets.read('${ProviderConfigResolver.accessTokenKey}:stocks'),
      'fhub-from-dotenv',
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
