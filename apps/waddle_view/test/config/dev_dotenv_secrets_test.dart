import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/config/dev_dotenv_secrets.dart';
import 'package:waddle_view/secrets/in_memory_secret_store.dart';

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
  });
}
