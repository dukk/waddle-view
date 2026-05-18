import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 2 to 3 adds secret tables and disables env-dependent integrations',
      () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE integrations (
  id TEXT NOT NULL PRIMARY KEY,
  provider_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  base_url TEXT,
  config_json TEXT,
  config_json_schema TEXT,
  example_config_json TEXT
);
''');
      for (final id in kIntegrationsDisabledOnSecretStoreMigration) {
        raw.execute(
          "INSERT INTO integrations (id, provider_type, enabled) "
          "VALUES ('$id', '$id', 1)",
        );
      }
      raw.execute(
        "INSERT INTO integrations (id, provider_type, enabled) "
        "VALUES ('news_rss', 'news_rss', 1)",
      );
      raw.execute('PRAGMA user_version = 2');
    });
    final connection = DatabaseConnection(
      executor,
      closeStreamsSynchronously: true,
    );

    final db = AppDatabase(connection);
    await db.customStatement('SELECT 1');

    final secretTables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('integration_secrets', 'secret_store_meta')",
    ).get();
    expect(secretTables.length, 2);

    Future<void> expectAllRowsDisabled(String integrationType) async {
      final rows = await (db.select(db.integrations)
            ..where((t) => t.integrationType.equals(integrationType)))
          .get();
      expect(rows, isNotEmpty, reason: integrationType);
      for (final row in rows) {
        expect(row.enabled, isFalse);
      }
    }

    await expectAllRowsDisabled('joke_openai');
    await expectAllRowsDisabled('trivia_openai');
    await expectAllRowsDisabled('weather_openweathermap');
    await expectAllRowsDisabled('photo_pexels');
    await expectAllRowsDisabled('video_pexels');
    await expectAllRowsDisabled('photo_flickr');
    await expectAllRowsDisabled('stock_finnhub');
    await expectAllRowsDisabled('calendar_google');
    await expectAllRowsDisabled('calendar_outlook');
    await expectAllRowsDisabled('photo_onedrive');
    await expectAllRowsDisabled('video_onedrive');

    final rss = await (db.select(db.integrations)
          ..where((t) => t.integrationType.equals('news_rss')))
        .getSingle();
    expect(rss.enabled, isTrue);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), greaterThanOrEqualTo(3));

    await db.close();
  });
}
