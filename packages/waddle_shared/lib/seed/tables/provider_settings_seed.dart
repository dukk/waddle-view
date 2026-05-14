import 'package:drift/drift.dart';

import 'package:waddle_shared/persistence/config_json_documentation.dart';
import 'package:waddle_shared/persistence/database.dart';

/// Inserts the stub provider when missing. Returns `true` if a row was added.
Future<bool> ensureStubProviderRow(AppDatabase db) async {
  final existing =
      await (db.select(db.providerSettings)..where((t) => t.id.equals('stub')))
          .getSingleOrNull();
  if (existing != null) {
    return false;
  }
  final stubDoc = providerConfigJsonDocForType('stub');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'stub',
          providerType: 'stub',
          enabled: const Value(true),
          pollSeconds: const Value(60),
          configJsonSchema: Value(stubDoc.schema),
          exampleConfigJson: Value(stubDoc.example),
        ),
      );
  return true;
}

Future<void> _ensureProviderRow(
  AppDatabase db, {
  required String id,
  required String providerType,
  required int pollSeconds,
}) async {
  final row =
      await (db.select(db.providerSettings)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType(providerType);
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: id,
          providerType: providerType,
          enabled: const Value(true),
          pollSeconds: Value(pollSeconds),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensureJokesProviderRow(AppDatabase db) async {
  final row =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('joke_openai')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final jokesDoc = providerConfigJsonDocForType('joke_openai');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'joke_openai',
          providerType: 'joke_openai',
          enabled: const Value(true),
          pollSeconds: const Value(3600),
          configJson: const Value(
            '{"jokesPerDay":10,"maxJokesPerTwoHours":20,"twoHourWindowMs":7200000,'
            '"jokeRetentionDays":14,"model":"gpt-4o-mini",'
            '"globalPrompt":"You write original, family-friendly jokes."}',
          ),
          configJsonSchema: Value(jokesDoc.schema),
          exampleConfigJson: Value(jokesDoc.example),
        ),
      );
}

Future<void> _ensureTriviaProviderRow(AppDatabase db) async {
  final row =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('trivia_openai')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final triviaDoc = providerConfigJsonDocForType('trivia_openai');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'trivia_openai',
          providerType: 'trivia_openai',
          enabled: const Value(true),
          pollSeconds: const Value(3600),
          configJson: const Value(
            '{"maxQuestionPerDay":200,"maxQuestionPerHour":20,'
            '"twoHourWindowMs":3600000,"questionRetentionDays":15,'
            '"model":"gpt-4o-mini"}',
          ),
          configJsonSchema: Value(triviaDoc.schema),
          exampleConfigJson: Value(triviaDoc.example),
        ),
      );
}

Future<void> _ensureOpenTdbTriviaProviderRow(AppDatabase db) async {
  final row = await (db.select(db.providerSettings)
        ..where((t) => t.id.equals('trivia_opentdb')))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('trivia_opentdb');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'trivia_opentdb',
          providerType: 'trivia_opentdb',
          enabled: const Value(false),
          pollSeconds: const Value(3600),
          baseUrl: const Value('https://opentdb.com/api.php'),
          configJson: const Value(
            '{"amount":10,"questionType":"multiple","categoryMap":{"science":17,"history":23}}',
          ),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensureWeatherProviderRow(AppDatabase db) async {
  final row =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('weather_openweathermap')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final weatherDoc = providerConfigJsonDocForType('weather_openweathermap');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'weather_openweathermap',
          providerType: 'weather_openweathermap',
          enabled: const Value(true),
          pollSeconds: const Value(900),
          baseUrl: const Value('https://api.openweathermap.org'),
          configJson: const Value(
            '{"units":"imperial","lang":"en","hourlyCount":6,'
            '"defaultLocation":{"name":"Default","lat":40.7128,"lon":-74.0060}}',
          ),
          configJsonSchema: Value(weatherDoc.schema),
          exampleConfigJson: Value(weatherDoc.example),
        ),
      );
}

Future<void> _ensureNwsWeatherAlertsProviderRow(AppDatabase db) async {
  final row =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('weather_nws_alerts')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('weather_nws_alerts');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'weather_nws_alerts',
          providerType: 'weather_nws_alerts',
          enabled: const Value(true),
          pollSeconds: const Value(900),
          baseUrl: const Value('https://api.weather.gov'),
          configJson: const Value(
            '{"userAgent":"(waddle-display, operator@example.com)",'
            '"defaultLocation":{"name":"Default","lat":40.7128,"lon":-74.0060}}',
          ),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensureGoogleCalendarProviderRow(AppDatabase db) async {
  final row = await (db.select(db.providerSettings)
        ..where((t) => t.id.equals('calendar_google')))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('calendar_google');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'calendar_google',
          providerType: 'calendar_google',
          enabled: const Value(false),
          pollSeconds: const Value(3600),
          baseUrl: const Value('https://www.googleapis.com/calendar/v3'),
          configJson: const Value(
            '{"accounts":[],"pastDays":14,"futureDays":14}',
          ),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensureOutlookCalendarProviderRow(AppDatabase db) async {
  final row =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('calendar_outlook')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final outlookDoc = providerConfigJsonDocForType('calendar_outlook');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'calendar_outlook',
          providerType: 'calendar_outlook',
          enabled: const Value(false),
          pollSeconds: const Value(3600),
          baseUrl: const Value('https://graph.microsoft.com/v1.0'),
          configJson: const Value(
            '{"accounts":[],"pastDays":14,"futureDays":14}',
          ),
          configJsonSchema: Value(outlookDoc.schema),
          exampleConfigJson: Value(outlookDoc.example),
        ),
      );
}

Future<void> _ensureOneDriveMediaProviderRow(AppDatabase db) async {
  final row =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('media_onedrive')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('media_onedrive');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'media_onedrive',
          providerType: 'media_onedrive',
          enabled: const Value(false),
          pollSeconds: const Value(3600),
          baseUrl: const Value('https://graph.microsoft.com/v1.0'),
          configJson: const Value(
            '{"accounts":[],"globalPerPollLimit":50}',
          ),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensureFlickrMediaProviderRow(AppDatabase db) async {
  final row =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('media_flickr')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('media_flickr');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'media_flickr',
          providerType: 'media_flickr',
          enabled: const Value(false),
          pollSeconds: const Value(3600),
          baseUrl: const Value('https://api.flickr.com/services/rest'),
          configJson: const Value(
            '{"groupIds":[],"category":"flickr","perPollLimit":20,"sort":"date-posted-desc"}',
          ),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensureBingImageOfDayProviderRow(AppDatabase db) async {
  final row =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('media_bing_iotd')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('media_bing_iotd');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'media_bing_iotd',
          providerType: 'media_bing_iotd',
          enabled: const Value(true),
          pollSeconds: const Value(3600),
          baseUrl: const Value('https://www.bing.com'),
          configJson: const Value(
            '{"retentionDays":1,"market":"en-US","resolution":"UHD","category":"bing"}',
          ),
          configJsonSchema: Value(doc.schema),
          exampleConfigJson: Value(doc.example),
        ),
      );
}

Future<void> _ensurePexelsProviderRow(AppDatabase db) async {
  final row =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('media_pexels')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final pexelsDoc = providerConfigJsonDocForType('media_pexels');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'media_pexels',
          providerType: 'media_pexels',
          enabled: const Value(true),
          pollSeconds: const Value(1800),
          baseUrl: const Value('https://api.pexels.com'),
          configJson: const Value(
            '{"maxPhotos":100,"maxVideos":100,"photosPerHour":2,"videosPerHour":2,'
            '"minVideoSeconds":5,"maxVideoSeconds":29,"sources":['
            '{"query":"Nature","category":"nature"},'
            '{"query":"Flowers","category":"flowers"},'
            '{"query":"Landscape","category":"landscape"},'
            '{"query":"Beach","category":"beach"},'
            '{"query":"Mountains","category":"mountains"},'
            '{"query":"Motivational","category":"motivational"},'
            '{"query":"Aquarium","category":"aquarium"}]}',
          ),
          configJsonSchema: Value(pexelsDoc.schema),
          exampleConfigJson: Value(pexelsDoc.example),
        ),
      );
}

Future<void> _ensureStocksProviderRow(AppDatabase db) async {
  final row =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('stock_finnhub')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final stocksDoc = providerConfigJsonDocForType('stock_finnhub');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'stock_finnhub',
          providerType: 'stock_finnhub',
          enabled: const Value(true),
          pollSeconds: const Value(300),
          baseUrl: const Value('https://finnhub.io'),
          configJson: const Value(
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
          ),
          configJsonSchema: Value(stocksDoc.schema),
          exampleConfigJson: Value(stocksDoc.example),
        ),
      );
}

/// Default [ProviderSettings] rows (stub handled separately).
Future<void> ensureProviderSettingsDefaults(AppDatabase db) async {
  await _ensureProviderRow(
    db,
    id: 'news_rss',
    providerType: 'news_rss',
    pollSeconds: 3600,
  );
  await _ensureJokesProviderRow(db);
  await _ensureTriviaProviderRow(db);
  await _ensureOpenTdbTriviaProviderRow(db);
  await _ensureWeatherProviderRow(db);
  await _ensureNwsWeatherAlertsProviderRow(db);
  await _ensurePexelsProviderRow(db);
  await _ensureStocksProviderRow(db);
  await _ensureGoogleCalendarProviderRow(db);
  await _ensureOutlookCalendarProviderRow(db);
  await _ensureOneDriveMediaProviderRow(db);
  await _ensureFlickrMediaProviderRow(db);
  await _ensureBingImageOfDayProviderRow(db);
}
