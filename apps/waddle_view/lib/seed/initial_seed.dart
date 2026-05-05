import 'package:drift/drift.dart';

import '../persistence/database.dart';
import '../persistence/tables.dart';
import 'joke_category_seed.dart';
import 'rss_news_feed_seed.dart';

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
  await ensureDefaultJokeCategories(db);
  await ensureDefaultRssNewsFeeds(db);
  await _ensureCuratorSettings(db);
  await _ensureWelcomeScreen(db);
  await _ensureJokeScreen(db);
  await _ensureGuestWifiScreen(db);
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
