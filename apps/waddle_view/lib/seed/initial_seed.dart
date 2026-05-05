import 'package:drift/drift.dart';

import '../persistence/database.dart';
import '../persistence/tables.dart';
import 'joke_category_seed.dart';
import 'rss_news_feed_seed.dart';
import 'trivia_category_seed.dart';

/// Idempotent demo rows for stub provider + ticker.
Future<void> ensureInitialSeed(AppDatabase db) async {
  final existing =
      await (db.select(db.providerSettings)
            ..where((t) => t.id.equals('stub')))
          .getSingleOrNull();
  if (existing == null) {
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'stub',
            providerType: 'stub',
            enabled: const Value(true),
            pollSeconds: const Value(60),
          ),
        );
    await db.into(db.dashboardKv).insertOnConflictUpdate(
          DashboardKvCompanion.insert(
            key: 'ticker.marquee.news',
            value: 'Welcome to Waddle View',
          ),
        );
    await db.into(db.dashboardKv).insertOnConflictUpdate(
          DashboardKvCompanion.insert(
            key: 'ticker.marquee.weather',
            value: '— °F · demo',
          ),
        );
    await db.into(db.dashboardKv).insertOnConflictUpdate(
          DashboardKvCompanion.insert(
            key: 'ticker.marquee.quote',
            value: 'Market data updates after each collect',
          ),
        );
  }
  await _ensureProviderRow(
    db,
    id: 'rss',
    providerType: 'rss',
    pollSeconds: 3600,
  );
  await _ensureJokesProviderRow(db);
  await _ensureTriviaProviderRow(db);
  await _ensureWeatherProviderRow(db);
  await _ensureDefaultWeatherLocations(db);
  await ensureDefaultJokeCategories(db);
  await ensureDefaultTriviaCategories(db);
  await ensureDefaultRssNewsFeeds(db);
  await _ensureCuratorSettings(db);
  await _ensureWelcomeScreen(db);
  await _ensureJokeScreen(db);
  await _ensureTriviaScreen(db);
  await _ensureGuestWifiScreen(db);
  await _ensureNewsScreen(db);
  await _ensureClockDataKeyLimit(db);
  await _ensureClockDigitalScreen(db);
  await _ensureClockAnalogScreen(db);
  await _ensureCalendarScreen(db);
  await _ensureLocalApiScreen(db);
  await _ensureAdminSetupScreen(db);
  await _ensureWeatherScreen(db);
}

Future<void> _ensureCuratorSettings(AppDatabase db) async {
  final row = await (db.select(db.curatorSettings)
        ..where((t) => t.id.equals(kCuratorSettingsId)))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.curatorSettings).insert(
        CuratorSettingsCompanion.insert(id: kCuratorSettingsId),
      );
  await db.into(db.dashboardKv).insertOnConflictUpdate(
        DashboardKvCompanion.insert(
          key: 'curator.news.require_photo_for_curation',
          value: 'true',
        ),
      );
}

Future<void> _ensureWelcomeScreen(AppDatabase db) async {
  final row = await (db.select(db.screenDefinitions)
        ..where((t) => t.id.equals('welcome')))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.screenDefinitions).insert(
        ScreenDefinitionsCompanion.insert(
          id: 'welcome',
          name: 'Welcome',
          description: const Value('Demo display screen'),
          layoutJson: const Value(
            '{"v":1,"layout":"single","widgets":[{"type":"static_text","slot":"main","config":{"text":"Welcome to Waddle View"}}]}',
          ),
          dwellMs: const Value(10000),
        ),
      );
}

Future<void> _ensureJokeScreen(AppDatabase db) async {
  final row = await (db.select(db.screenDefinitions)
        ..where((t) => t.id.equals('jokes')))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.screenDefinitions).insert(
        ScreenDefinitionsCompanion.insert(
          id: 'jokes',
          name: 'Jokes',
          description: const Value('Random joke with delayed punchline'),
          layoutJson: const Value(
            '{"v":1,"layout":"single","widgets":[{"type":"joke","slot":"main","config":{}}]}',
          ),
          dwellMs: const Value(12000),
        ),
      );
}

Future<void> _ensureTriviaScreen(AppDatabase db) async {
  final row = await (db.select(db.screenDefinitions)
        ..where((t) => t.id.equals('trivia')))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.screenDefinitions).insert(
        ScreenDefinitionsCompanion.insert(
          id: 'trivia',
          name: 'Trivia',
          description: const Value('Multiple-choice trivia with reveal countdown'),
          layoutJson: const Value(
            '{"v":1,"layout":"single","widgets":[{"type":"trivia","slot":"main","config":{}}]}',
          ),
          dwellMs: const Value(16000),
        ),
      );
}

Future<void> _ensureGuestWifiScreen(AppDatabase db) async {
  final row = await (db.select(db.screenDefinitions)
        ..where((t) => t.id.equals('guest_wifi')))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.screenDefinitions).insert(
        ScreenDefinitionsCompanion.insert(
          id: 'guest_wifi',
          name: 'Guest WiFi',
          description: const Value('QR and credentials for guest network'),
          layoutJson: const Value(
            '{"v":1,"layout":"single","widgets":[{"type":"guest_wifi","slot":"main","config":{}}]}',
          ),
          dwellMs: const Value(18000),
        ),
      );
}

Future<void> _ensureNewsScreen(AppDatabase db) async {
  final row = await (db.select(db.screenDefinitions)
        ..where((t) => t.id.equals('news')))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.screenDefinitions).insert(
        ScreenDefinitionsCompanion.insert(
          id: 'news',
          name: 'News',
          description: const Value('RSS story with image and scrolling summary'),
          layoutJson: const Value(
            '{"v":1,"layout":"single","widgets":[{"type":"rss_article","slot":"main","config":{"scrollDelayMs":2500,"trailingHoldMs":2000,"scrollPixelsPerSecond":48,"minReadMs":8000}}]}',
          ),
          dwellMs: const Value(12000),
        ),
      );
}

Future<void> _ensureClockDataKeyLimit(AppDatabase db) async {
  await db.into(db.curatorDataKeyProgramLimits).insertOnConflictUpdate(
        CuratorDataKeyProgramLimitsCompanion.insert(
          dataKey: 'clock',
          minPlacementsPerProgram: const Value(1),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureClockDigitalScreen(AppDatabase db) async {
  final row = await (db.select(db.screenDefinitions)
        ..where((t) => t.id.equals('clock_digital')))
      .getSingleOrNull();
  if (row != null) {
    await (db.update(db.screenDefinitions)
          ..where((t) => t.id.equals('clock_digital')))
        .write(
          const ScreenDefinitionsCompanion(
            dataKey: Value('clock'),
            minPlacementsPerProgram: Value(0),
            maxPlacementsPerProgram: Value(1),
          ),
        );
    return;
  }
  await db.into(db.screenDefinitions).insert(
        ScreenDefinitionsCompanion.insert(
          id: 'clock_digital',
          name: 'Digital clock',
          description: const Value('Local time and date'),
          layoutJson: const Value(
            '{"v":1,"layout":"single","widgets":[{"type":"digital_clock","slot":"main","config":{}}]}',
          ),
          dwellMs: const Value(16000),
          dataKey: const Value('clock'),
          minPlacementsPerProgram: const Value(0),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureClockAnalogScreen(AppDatabase db) async {
  final row = await (db.select(db.screenDefinitions)
        ..where((t) => t.id.equals('clock_analog')))
      .getSingleOrNull();
  if (row != null) {
    await (db.update(db.screenDefinitions)
          ..where((t) => t.id.equals('clock_analog')))
        .write(
          const ScreenDefinitionsCompanion(
            dataKey: Value('clock'),
            minPlacementsPerProgram: Value(0),
            maxPlacementsPerProgram: Value(1),
          ),
        );
    return;
  }
  await db.into(db.screenDefinitions).insert(
        ScreenDefinitionsCompanion.insert(
          id: 'clock_analog',
          name: 'Analog clock',
          description: const Value('Analog dial with local date'),
          layoutJson: const Value(
            '{"v":1,"layout":"single","widgets":[{"type":"analog_clock","slot":"main","config":{}}]}',
          ),
          dwellMs: const Value(16000),
          dataKey: const Value('clock'),
          minPlacementsPerProgram: const Value(0),
          maxPlacementsPerProgram: const Value(1),
        ),
      );
}

Future<void> _ensureCalendarScreen(AppDatabase db) async {
  final row = await (db.select(db.screenDefinitions)
        ..where((t) => t.id.equals('calendar')))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.screenDefinitions).insert(
        ScreenDefinitionsCompanion.insert(
          id: 'calendar',
          name: 'Calendar',
          description: const Value(
            'Month view with upcoming events; increase dwell_ms when many events need air time',
          ),
          layoutJson: const Value(
            '{"v":1,"layout":"single","widgets":[{"type":"calendar_month","slot":"main","config":{}}]}',
          ),
          dwellMs: const Value(22000),
        ),
      );
}

Future<void> _ensureLocalApiScreen(AppDatabase db) async {
  final row = await (db.select(db.screenDefinitions)
        ..where((t) => t.id.equals('dev_local_api')))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.screenDefinitions).insert(
        ScreenDefinitionsCompanion.insert(
          id: 'dev_local_api',
          name: 'Developer — Local API',
          description: const Value(
            'Loopback REST base URL and API key hint; enable when configuring deployments',
          ),
          enabled: const Value(false),
          layoutJson: const Value(
            '{"v":1,"layout":"single","widgets":[{"type":"local_api","slot":"main","config":{}}]}',
          ),
          dwellMs: const Value(16000),
        ),
      );
}

Future<void> _ensureAdminSetupScreen(AppDatabase db) async {
  final row = await (db.select(db.screenDefinitions)
        ..where((t) => t.id.equals('admin_setup')))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.screenDefinitions).insert(
        ScreenDefinitionsCompanion.insert(
          id: 'admin_setup',
          name: 'Setup Admin Access',
          description: const Value(
            'Onboarding URL, QR code, and bootstrap password for first login',
          ),
          enabled: const Value(true),
          layoutJson: const Value(
            '{"v":1,"layout":"single","widgets":[{"type":"admin_setup","slot":"main","config":{}}]}',
          ),
          dwellMs: const Value(18000),
          frequencyWeight: const Value(200),
          minGapBetweenShowsMs: const Value(0),
        ),
      );
}

Future<void> _ensureWeatherScreen(AppDatabase db) async {
  final row = await (db.select(db.screenDefinitions)
        ..where((t) => t.id.equals('weather')))
      .getSingleOrNull();
  if (row != null) {
    return;
  }
  await db.into(db.screenDefinitions).insert(
        ScreenDefinitionsCompanion.insert(
          id: 'weather',
          name: 'Weather',
          description: const Value('Current weather'),
          layoutJson: const Value(
            '{"v":1,"layout":"single","widgets":[{"type":"weather","slot":"main","config":{"locationId":"salt_lake_city_ut"}}]}',
          ),
          dwellMs: const Value(14000),
        ),
      );
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
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: id,
          providerType: providerType,
          enabled: const Value(true),
          pollSeconds: Value(pollSeconds),
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
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'jokes',
          providerType: 'jokes',
          enabled: const Value(true),
          pollSeconds: const Value(3600),
          extraJson: const Value(
            '{"jokesPerDay":3,"maxJokesPerTwoHours":20,"twoHourWindowMs":7200000,'
            '"jokeRetentionDays":14,"model":"gpt-4o-mini",'
            '"globalPrompt":"You write original, family-friendly jokes."}',
          ),
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
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'trivia',
          providerType: 'trivia',
          enabled: const Value(true),
          pollSeconds: const Value(3600),
          extraJson: const Value(
            '{"questionsPerDay":3,"maxQuestionsPerTwoHours":20,'
            '"twoHourWindowMs":7200000,"questionRetentionDays":14,'
            '"model":"gpt-4o-mini",'
            '"globalPrompt":"You write clear, family-friendly multiple-choice trivia."}',
          ),
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
  await db.into(db.providerSettings).insert(
        ProviderSettingsCompanion.insert(
          id: 'weather',
          providerType: 'weather',
          enabled: const Value(true),
          pollSeconds: const Value(900),
          baseUrl: const Value('https://api.openweathermap.org'),
          extraJson: const Value(
            '{"units":"imperial","lang":"en","hourlyCount":6,'
            '"defaultLocation":{"name":"Default","lat":40.7128,"lon":-74.0060}}',
          ),
        ),
      );
}

Future<void> _ensureDefaultWeatherLocations(AppDatabase db) async {
  await db.into(db.weatherLocations).insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'salt_lake_city_ut',
          name: 'Salt Lake City, UT',
          latitude: 40.7608,
          longitude: -111.8910,
          enabled: const Value(true),
        ),
      );
  await db.into(db.weatherLocations).insertOnConflictUpdate(
        WeatherLocationsCompanion.insert(
          id: 'atlanta_ga',
          name: 'Atlanta, GA',
          latitude: 33.7490,
          longitude: -84.3880,
          enabled: const Value(true),
        ),
      );
}
