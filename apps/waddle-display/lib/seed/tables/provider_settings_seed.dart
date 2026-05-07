import 'package:drift/drift.dart';

import '../../persistence/config_json_documentation.dart';
import '../../persistence/database.dart';

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
            ..where((t) => t.id.equals('jokes')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final jokesDoc = providerConfigJsonDocForType('jokes');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'jokes',
          providerType: 'jokes',
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
            ..where((t) => t.id.equals('trivia')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final triviaDoc = providerConfigJsonDocForType('trivia');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'trivia',
          providerType: 'trivia',
          enabled: const Value(true),
          pollSeconds: const Value(3600),
          configJson: const Value(
            '{"questionsPerDay":3,"maxQuestionsPerTwoHours":20,'
            '"twoHourWindowMs":7200000,"questionRetentionDays":14,'
            '"model":"gpt-4o-mini",'
            '"globalPrompt":"You write clear, family-friendly multiple-choice trivia."}',
          ),
          configJsonSchema: Value(triviaDoc.schema),
          exampleConfigJson: Value(triviaDoc.example),
        ),
      );
}

Future<void> _ensureWeatherProviderRow(AppDatabase db) async {
  final row =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('weather')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final weatherDoc = providerConfigJsonDocForType('weather');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'weather',
          providerType: 'weather',
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

Future<void> _ensureGoogleCalendarProviderRow(AppDatabase db) async {
  final row = await (db.select(db.providerSettings)
        ..where((t) => t.id.equals('google_calendar')))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('google_calendar');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'google_calendar',
          providerType: 'google_calendar',
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
            ..where((t) => t.id.equals('outlook_calendar')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final outlookDoc = providerConfigJsonDocForType('outlook_calendar');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'outlook_calendar',
          providerType: 'outlook_calendar',
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
            ..where((t) => t.id.equals('onedrive_media')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final doc = providerConfigJsonDocForType('onedrive_media');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'onedrive_media',
          providerType: 'onedrive_media',
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

Future<void> _ensurePexelsProviderRow(AppDatabase db) async {
  final row =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('pexels')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final pexelsDoc = providerConfigJsonDocForType('pexels');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'pexels',
          providerType: 'pexels',
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
            ..where((t) => t.id.equals('stocks')))
          .getSingleOrNull();
  if (row != null) {
    return;
  }
  final stocksDoc = providerConfigJsonDocForType('stocks');
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'stocks',
          providerType: 'stocks',
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
    id: 'rss',
    providerType: 'rss',
    pollSeconds: 3600,
  );
  await _ensureJokesProviderRow(db);
  await _ensureTriviaProviderRow(db);
  await _ensureWeatherProviderRow(db);
  await _ensurePexelsProviderRow(db);
  await _ensureStocksProviderRow(db);
  await _ensureGoogleCalendarProviderRow(db);
  await _ensureOutlookCalendarProviderRow(db);
  await _ensureOneDriveMediaProviderRow(db);
}
