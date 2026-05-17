/// Legacy env key names for provider API tokens and OAuth client ids.
///
/// **Deprecated for runtime:** integration secrets are configured via the
/// controller UI and stored in encrypted SQLite ([DbEncryptedSecretStore]).
/// These constants remain for documentation, migration notes, and tests that
/// assert env parsing helpers.
library;

/// OpenAI-style API key for jokes, trivia, and the OpenTDB path when it shares the resolver.
const String waddleOpenAiApiKeyEnv = 'WADDLE_DISPLAY_OPENAI_API_KEY';

/// OpenWeatherMap API key.
const String waddleOpenWeatherMapApiKeyEnv = 'WADDLE_DISPLAY_OPEN_WEATHER_MAP_API_KEY';

/// Pexels API key (https://www.pexels.com/api/).
const String waddlePexelsApiKeyEnv = 'WADDLE_DISPLAY_PEXELS_API_KEY';

/// Flickr REST API key (https://www.flickr.com/services/api/).
const String waddleFlickrApiKeyEnv = 'WADDLE_DISPLAY_FLICKR_API_KEY';

/// Finnhub API key (https://finnhub.io/) for the `stock_finnhub` provider.
const String waddleFinhubApiKeyEnv = 'WADDLE_DISPLAY_FINHUB_API_KEY';

/// Microsoft Entra (Azure AD) **application (client) id** for Graph OAuth
/// (Outlook calendar, OneDrive media). Not stored in SQLite.
const String waddleMicrosoftGraphClientIdEnv =
    'WADDLE_DISPLAY_MICROSOFT_GRAPH_CLIENT_ID';

/// Google OAuth **client id** for Calendar API device flow. Not stored in SQLite.
const String waddleGoogleClientIdEnv = 'WADDLE_DISPLAY_GOOGLE_CLIENT_ID';

String? _trimNonEmpty(String? v) {
  final t = v?.trim();
  if (t == null || t.isEmpty) {
    return null;
  }
  return t;
}

/// Microsoft Graph OAuth public client id from [map] (trimmed), or null.
String? readMicrosoftGraphClientIdFromEnvMap(Map<String, String> map) =>
    _trimNonEmpty(map[waddleMicrosoftGraphClientIdEnv]);

/// Google OAuth client id from [map] (trimmed), or null.
String? readGoogleClientIdFromEnvMap(Map<String, String> map) =>
    _trimNonEmpty(map[waddleGoogleClientIdEnv]);

/// Reads the jokes/OpenAI token from an env map.
String? readJokesTokenFromEnvMap(Map<String, String> map) =>
    _trimNonEmpty(map[waddleOpenAiApiKeyEnv]);

/// OpenAI-style token for trivia: same resolution as jokes.
String? readTriviaTokenFromEnvMap(Map<String, String> map) =>
    readJokesTokenFromEnvMap(map);

/// Weather provider token from env map.
String? readWeatherTokenFromEnvMap(Map<String, String> map) =>
    _trimNonEmpty(map[waddleOpenWeatherMapApiKeyEnv]);

/// Pexels provider API key from env map.
String? readPexelsTokenFromEnvMap(Map<String, String> map) =>
    _trimNonEmpty(map[waddlePexelsApiKeyEnv]);

/// Flickr provider API key from env map.
String? readFlickrTokenFromEnvMap(Map<String, String> map) =>
    _trimNonEmpty(map[waddleFlickrApiKeyEnv]);

/// Stocks provider token from env map.
String? readStocksTokenFromEnvMap(Map<String, String> map) =>
    _trimNonEmpty(map[waddleFinhubApiKeyEnv]);

/// Resolves the access token for [providerId] from [env] (process + optional
/// merged `.env` in debug). Providers without a dedicated static key mapping
/// return null.
String? resolveProviderAccessTokenFromEnv(
  String providerId,
  Map<String, String> env,
) {
  switch (providerId) {
    case 'joke_openai':
    case 'jokes':
      return readJokesTokenFromEnvMap(env);
    case 'trivia_openai':
    case 'trivia':
    case 'trivia_opentdb':
    case 'opentdb_trivia':
      return readTriviaTokenFromEnvMap(env);
    case 'weather_openweathermap':
    case 'weather':
      return readWeatherTokenFromEnvMap(env);
    case 'photo_pexels':
    case 'video_pexels':
    case 'media_pexels':
    case 'pexels':
      return readPexelsTokenFromEnvMap(env);
    case 'photo_flickr':
    case 'media_flickr':
    case 'flickr_media':
      return readFlickrTokenFromEnvMap(env);
    case 'stock_finnhub':
    case 'stocks':
      return readStocksTokenFromEnvMap(env);
    default:
      return null;
  }
}
