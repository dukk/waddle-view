import 'package:drift/drift.dart';

import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/database.dart';

Future<void> _ensureIntegrationRow(
  AppDatabase db, {
  required String id,
  required String integrationType,
  required int pollSeconds,
  bool enabled = true,
  String? baseUrl,
  String? configJson,
}) async {
  final row =
      await (db.select(db.integrations)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType(integrationType);
  await db.into(db.integrations).insert(
        IntegrationsCompanion.insert(
          id: id,
          integrationType: integrationType,
          enabled: Value(enabled),
          pollSeconds: Value(pollSeconds),
          baseUrl: baseUrl == null ? const Value.absent() : Value(baseUrl),
          configJson:
              configJson == null ? const Value.absent() : Value(configJson),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> ensureIntegrationsDefaults(AppDatabase db) async {
  await _ensureIntegrationRow(
    db,
    id: kDefaultNewsRssIntegrationId,
    integrationType: 'news_rss',
    pollSeconds: 3600,
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultNewsFacebookIntegrationId,
    integrationType: 'news_facebook',
    pollSeconds: 3600,
    enabled: false,
    baseUrl: 'https://graph.facebook.com',
    configJson: '{"accounts":[]}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultNewsTwitterIntegrationId,
    integrationType: 'news_twitter',
    pollSeconds: 3600,
    enabled: false,
    baseUrl: 'https://api.twitter.com',
    configJson: '{"accounts":[]}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultNewsLinkedinIntegrationId,
    integrationType: 'news_linkedin',
    pollSeconds: 3600,
    enabled: false,
    baseUrl: 'https://api.linkedin.com',
    configJson: '{"accounts":[]}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultJokeOpenAiIntegrationId,
    integrationType: 'joke_openai',
    pollSeconds: 3600,
    enabled: false,
    configJson:
        '{"jokesPerDay":10,"maxJokesPerTwoHours":20,"twoHourWindowMs":7200000,'
        '"jokeRetentionDays":14,"model":"gpt-4o-mini",'
        '"globalPrompt":"You write original, family-friendly jokes."}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultTriviaOpenAiIntegrationId,
    integrationType: 'trivia_openai',
    pollSeconds: 3600,
    enabled: false,
    configJson:
        '{"maxQuestionPerDay":200,"maxQuestionPerHour":20,'
        '"twoHourWindowMs":3600000,"questionRetentionDays":15,'
        '"model":"gpt-4o-mini"}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultTriviaOpenTdbIntegrationId,
    integrationType: 'trivia_opentdb',
    pollSeconds: 3600,
    enabled: false,
    baseUrl: 'https://opentdb.com/api.php',
    configJson:
        '{"amount":10,"questionType":"multiple","categoryMap":{"science":17,"history":23}}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultWeatherOpenWeatherMapIntegrationId,
    integrationType: 'weather_openweathermap',
    pollSeconds: 900,
    enabled: false,
    baseUrl: 'https://api.openweathermap.org',
    configJson:
        '{"units":"imperial","lang":"en","hourlyCount":6,'
        '"defaultLocation":{"name":"Default","lat":40.7128,"lon":-74.0060}}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultWeatherAlertsNwsIntegrationId,
    integrationType: 'weather_alerts_nws',
    pollSeconds: 900,
    baseUrl: 'https://api.weather.gov',
    configJson:
        '{"userAgent":"(waddle-display, operator@example.com)",'
        '"defaultLocation":{"name":"Default","lat":40.7128,"lon":-74.0060}}',
  );

  const pexelsSources =
      '[{"query":"Nature","category":"nature"},'
      '{"query":"Flowers","category":"flowers"},'
      '{"query":"Landscape","category":"landscape"},'
      '{"query":"Beach","category":"beach"},'
      '{"query":"Mountains","category":"mountains"},'
      '{"query":"Motivational","category":"motivational"},'
      '{"query":"Aquarium","category":"aquarium"}]';

  await _ensureIntegrationRow(
    db,
    id: kDefaultPhotoPexelsIntegrationId,
    integrationType: 'photo_pexels',
    pollSeconds: 1800,
    enabled: false,
    baseUrl: 'https://api.pexels.com',
    configJson:
        '{"maxPhotos":100,"photosPerHour":2,"sources":$pexelsSources}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultVideoPexelsIntegrationId,
    integrationType: 'video_pexels',
    pollSeconds: 1800,
    enabled: false,
    baseUrl: 'https://api.pexels.com',
    configJson:
        '{"maxVideos":100,"videosPerHour":2,"minVideoSeconds":5,"maxVideoSeconds":29,'
        '"sources":$pexelsSources}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultStockFinnhubIntegrationId,
    integrationType: 'stock_finnhub',
    pollSeconds: 300,
    enabled: true,
    baseUrl: 'https://finnhub.io',
    configJson:
        '{"maxSymbolsPerCollect":25,"defaultSymbols":['
        '{"symbol":"AAPL","displayName":"Apple"},'
        '{"symbol":"MSFT","displayName":"Microsoft"},'
        '{"symbol":"GOOG","displayName":"Alphabet"},'
        '{"symbol":"NVDA","displayName":"NVIDIA"},'
        '{"symbol":"AMZN","displayName":"Amazon"}'
        '{"symbol":"TSLA","displayName":"Tesla"},'
        '{"symbol":"META","displayName":"Meta"},'
        '{"symbol":"NFLX","displayName":"Netflix"},'
        '{"symbol":"DIS","displayName":"Disney"},'
        '{"symbol":"IBM","displayName":"IBM"},'
        '{"symbol":"CSCO","displayName":"Cisco"},'
        '{"symbol":"INTC","displayName":"Intel"},'
        '{"symbol":"ORCL","displayName":"Oracle"},'
        '{"symbol":"VOO","displayName":"Vanguard S&P 500 ETF"},'
        '{"symbol":"SPY","displayName":"SPDR S&P 500 ETF"},'
        '{"symbol":"QQQ","displayName":"Invesco QQQ Trust"},'
        '{"symbol":"IWM","displayName":"iShares Russell 2000 ETF"},'
        ']}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultHomeAssistantIntegrationId,
    integrationType: 'home_assistant',
    pollSeconds: 60,
    enabled: false,
    baseUrl: 'http://homeassistant.local:8123',
    configJson:
        '{"maxEntitiesPerCollect":50,"requestTimeoutMs":15000,'
        '"defaultEntities":[]}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultCalendarGoogleIntegrationId,
    integrationType: 'calendar_google',
    pollSeconds: 3600,
    enabled: false,
    baseUrl: 'https://www.googleapis.com/calendar/v3',
    configJson: '{"accounts":[],"pastDays":14,"futureDays":14}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultCalendarOutlookIntegrationId,
    integrationType: 'calendar_outlook',
    pollSeconds: 3600,
    enabled: false,
    baseUrl: 'https://graph.microsoft.com/v1.0',
    configJson: '{"accounts":[],"pastDays":14,"futureDays":14}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultCalendarIcalIntegrationId,
    integrationType: 'calendar_ical',
    pollSeconds: 3600,
    enabled: false,
    configJson: '{"feeds":[],"pastDays":14,"futureDays":14}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultPhotoOneDriveIntegrationId,
    integrationType: 'photo_onedrive',
    pollSeconds: 3600,
    enabled: false,
    baseUrl: 'https://graph.microsoft.com/v1.0',
    configJson: '{"accounts":[],"globalPerPollLimit":50}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultVideoOneDriveIntegrationId,
    integrationType: 'video_onedrive',
    pollSeconds: 3600,
    enabled: false,
    baseUrl: 'https://graph.microsoft.com/v1.0',
    configJson: '{"accounts":[],"globalPerPollLimit":50}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultPhotoFlickrIntegrationId,
    integrationType: 'photo_flickr',
    pollSeconds: 3600,
    enabled: false,
    baseUrl: 'https://api.flickr.com/services/rest',
    configJson:
        '{"groupIds":[],"category":"flickr","perPollLimit":20,"sort":"date-posted-desc"}',
  );

  await _ensureIntegrationRow(
    db,
    id: kDefaultPhotoBingIotdIntegrationId,
    integrationType: 'photo_bing_image_of_the_day',
    pollSeconds: 3600,
    baseUrl: 'https://www.bing.com',
    configJson:
        '{"retentionDays":1,"market":"en-US","resolution":"UHD","category":"bing"}',
  );
}
