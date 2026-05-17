import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/config/dev_dotenv_secrets.dart';

void main() {
  test('mergeBootstrapEnv starts from Platform.environment', () {
    dotenv.clean();
    final merged = mergeBootstrapEnv();
    expect(merged.length, greaterThanOrEqualTo(Platform.environment.length));
    for (final e in Platform.environment.entries) {
      expect(merged[e.key], e.value);
    }
  });

  test('mergeBootstrapEnv lets dotenv override duplicate keys', () {
    dotenv.clean();
    dotenv.loadFromString(
      envString: 'WADDLE_MERGE_TEST_KEY=from_dotenv',
      isOptional: true,
    );
    final merged = mergeBootstrapEnv();
    expect(merged['WADDLE_MERGE_TEST_KEY'], 'from_dotenv');
  });

  test('readJokesTokenFromEnvMap reads WADDLE_DISPLAY_OPENAI_API_KEY', () {
    expect(
      readJokesTokenFromEnvMap({
        waddleOpenAiApiKeyEnv: '  sk-waddle  ',
      }),
      'sk-waddle',
    );
  });

  test('readJokesTokenFromEnvMap returns null when empty or missing', () {
    expect(readJokesTokenFromEnvMap({}), isNull);
    expect(
      readJokesTokenFromEnvMap({
        waddleOpenAiApiKeyEnv: '  ',
      }),
      isNull,
    );
  });

  test('readTriviaTokenFromEnvMap uses same keys as jokes', () {
    expect(
      readTriviaTokenFromEnvMap({
        waddleOpenAiApiKeyEnv: ' sk-shared ',
      }),
      'sk-shared',
    );
  });

  test('readWeatherTokenFromEnvMap reads WADDLE_DISPLAY_OPEN_WEATHER_MAP_API_KEY', () {
    expect(
      readWeatherTokenFromEnvMap({
        waddleOpenWeatherMapApiKeyEnv: ' owm-token ',
      }),
      'owm-token',
    );
  });

  test('readPexelsTokenFromEnvMap reads WADDLE_DISPLAY_PEXELS_API_KEY', () {
    expect(
      readPexelsTokenFromEnvMap({
        waddlePexelsApiKeyEnv: ' pex-a ',
      }),
      'pex-a',
    );
  });

  test('readFlickrTokenFromEnvMap reads WADDLE_DISPLAY_FLICKR_API_KEY', () {
    expect(
      readFlickrTokenFromEnvMap({
        waddleFlickrApiKeyEnv: ' fl-a ',
      }),
      'fl-a',
    );
  });

  test('readStocksTokenFromEnvMap reads WADDLE_DISPLAY_FINHUB_API_KEY', () {
    expect(
      readStocksTokenFromEnvMap({waddleFinhubApiKeyEnv: ' fhub-token '}),
      'fhub-token',
    );
  });

  test('readStocksTokenFromEnvMap returns null when empty', () {
    expect(readStocksTokenFromEnvMap({}), isNull);
    expect(
      readStocksTokenFromEnvMap({
        waddleFinhubApiKeyEnv: '   ',
      }),
      isNull,
    );
  });

  test(
    'loadDevDotenvFromFilesystem initializes empty dotenv when no candidate files exist',
    () async {
      final tmp = await Directory.systemTemp.createTemp('waddle_dotenv_');
      final prev = Directory.current;
      try {
        Directory.current = tmp;
        dotenv.clean();
        await loadDevDotenvFromFilesystem();
        expect(dotenv.isInitialized, isTrue);
        final merged = mergeBootstrapEnv();
        expect(merged.length, greaterThanOrEqualTo(Platform.environment.length));
      } finally {
        Directory.current = prev;
        await tmp.delete(recursive: true);
      }
    },
  );
}
