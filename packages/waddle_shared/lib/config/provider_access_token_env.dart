/// Env keys and readers for **non-OAuth** provider API tokens (never SQLite).
///
/// OAuth tokens for Google / Microsoft Graph stay in [SecretStore]; these
/// helpers back [ProviderConfigResolver] with `Platform.environment` and/or
/// merged debug `.env` maps.
library;

/// Env key for an OpenAI-style API token (common ecosystem convention).
const String openAiApiKeyEnv = 'OPENAI_API_KEY';

/// Optional explicit key so a shared `.env` can scope the joke provider token.
const String waddleJokesAccessTokenKey = 'WADDLE_JOKES_ACCESS_TOKEN';

/// Optional override for the trivia provider; otherwise same resolution as jokes.
const String waddleTriviaAccessTokenKey = 'WADDLE_TRIVIA_ACCESS_TOKEN';

/// API key for OpenWeatherMap weather provider.
const String openWeatherMapApiKeyEnv = 'OPEN_WEATHER_MAP_API_KEY';

/// Pexels API key (https://www.pexels.com/api/).
const String pexelsApiKeyEnv = 'PEXELS_API_KEY';

/// Optional explicit Pexels key (otherwise [pexelsApiKeyEnv]).
const String waddlePexelsAccessTokenKey = 'WADDLE_PEXELS_ACCESS_TOKEN';

/// Flickr REST API key (https://www.flickr.com/services/api/).
const String flickrApiKeyEnv = 'FLICKR_API_KEY';

/// Optional explicit Flickr key (otherwise [flickrApiKeyEnv]).
const String waddleFlickrAccessTokenKey = 'WADDLE_FLICKR_ACCESS_TOKEN';

/// Finnhub API key (https://finnhub.io/) for the `stocks` provider.
const String finnhubApiKeyEnv = 'FINNHUB_API_KEY';

/// Optional explicit Finnhub key (otherwise [finnhubApiKeyEnv]).
const String waddleStocksAccessTokenKey = 'WADDLE_STOCKS_ACCESS_TOKEN';

/// Prefix for Microsoft Graph OAuth tokens in debug `.env` files.
///
/// Pair with [waddleMsGraphRefreshTokenPrefix]: for account key `work`, set
/// `WADDLE_MSGRAPH_ACCESS_TOKEN_work` and optionally `WADDLE_MSGRAPH_REFRESH_TOKEN_work`.
const String waddleMsGraphAccessTokenPrefix = 'WADDLE_MSGRAPH_ACCESS_TOKEN_';

/// See [waddleMsGraphAccessTokenPrefix].
const String waddleMsGraphRefreshTokenPrefix = 'WADDLE_MSGRAPH_REFRESH_TOKEN_';

/// Prefix for Google OAuth access tokens in debug `.env` files.
const String waddleGoogleAccessTokenPrefix = 'WADDLE_GOOGLE_ACCESS_TOKEN_';

/// Prefix for Google OAuth refresh tokens in debug `.env` files.
const String waddleGoogleRefreshTokenPrefix = 'WADDLE_GOOGLE_REFRESH_TOKEN_';

/// Generic fallback: `WADDLE_PROVIDER_ACCESS_TOKEN_<UPPER_SNAKE>` derived from
/// [providerId] (e.g. `opentdb_trivia` → …`_OPENTDB_TRIVIA`).
String waddleProviderAccessTokenEnvKey(String providerId) {
  final snake = providerId
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .toUpperCase();
  return 'WADDLE_PROVIDER_ACCESS_TOKEN_$snake';
}

String? _trimNonEmpty(String? v) {
  final t = v?.trim();
  if (t == null || t.isEmpty) {
    return null;
  }
  return t;
}

/// Reads the jokes/OpenAI token from an env map.
String? readJokesTokenFromEnvMap(Map<String, String> map) {
  final explicit = _trimNonEmpty(map[waddleJokesAccessTokenKey]);
  if (explicit != null) {
    return explicit;
  }
  return _trimNonEmpty(map[openAiApiKeyEnv]);
}

/// OpenAI-style token for trivia: explicit trivia key, else same as jokes/OpenAI.
String? readTriviaTokenFromEnvMap(Map<String, String> map) {
  final explicit = _trimNonEmpty(map[waddleTriviaAccessTokenKey]);
  if (explicit != null) {
    return explicit;
  }
  return readJokesTokenFromEnvMap(map);
}

/// Weather provider token from env map.
String? readWeatherTokenFromEnvMap(Map<String, String> map) =>
    _trimNonEmpty(map[openWeatherMapApiKeyEnv]);

/// Pexels provider API key from env map.
String? readPexelsTokenFromEnvMap(Map<String, String> map) {
  final explicit = _trimNonEmpty(map[waddlePexelsAccessTokenKey]);
  if (explicit != null) {
    return explicit;
  }
  return _trimNonEmpty(map[pexelsApiKeyEnv]);
}

/// Flickr provider API key from env map.
String? readFlickrTokenFromEnvMap(Map<String, String> map) {
  final explicit = _trimNonEmpty(map[waddleFlickrAccessTokenKey]);
  if (explicit != null) {
    return explicit;
  }
  return _trimNonEmpty(map[flickrApiKeyEnv]);
}

/// Stocks provider token from env map.
String? readStocksTokenFromEnvMap(Map<String, String> map) {
  final explicit = _trimNonEmpty(map[waddleStocksAccessTokenKey]);
  if (explicit != null) {
    return explicit;
  }
  return _trimNonEmpty(map[finnhubApiKeyEnv]);
}

/// Resolves the access token for [providerId] from [env] (process + optional
/// merged `.env` in debug).
String? resolveProviderAccessTokenFromEnv(
  String providerId,
  Map<String, String> env,
) {
  switch (providerId) {
    case 'jokes':
      return readJokesTokenFromEnvMap(env);
    case 'trivia':
    case 'opentdb_trivia':
      return readTriviaTokenFromEnvMap(env);
    case 'weather':
      return readWeatherTokenFromEnvMap(env);
    case 'pexels':
      return readPexelsTokenFromEnvMap(env);
    case 'flickr_media':
      return readFlickrTokenFromEnvMap(env);
    case 'stocks':
      return readStocksTokenFromEnvMap(env);
    default:
      return _trimNonEmpty(env[waddleProviderAccessTokenEnvKey(providerId)]);
  }
}
