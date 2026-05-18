import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 9 to 10 creates integration_account_links', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE integrations (
  id TEXT NOT NULL PRIMARY KEY,
  integration_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  base_url TEXT,
  config_json TEXT,
  config_json_schema TEXT,
  example_config_json TEXT
);
''');
      raw.execute('''
CREATE TABLE integration_accounts (
  id TEXT NOT NULL PRIMARY KEY,
  account_type TEXT NOT NULL,
  label TEXT,
  created_at_ms INTEGER NOT NULL
);
''');
      raw.execute('''
CREATE TABLE interests_locations (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  include_weather INTEGER NOT NULL DEFAULT 1,
  include_weather_alerts INTEGER NOT NULL DEFAULT 0,
  include_local_news INTEGER NOT NULL DEFAULT 0,
  category TEXT NOT NULL DEFAULT 'general'
);
''');
      raw.execute(
        "INSERT INTO integrations (id, integration_type, enabled, config_json) "
        "VALUES ('$kDefaultCalendarGoogleIntegrationId', 'calendar_google', 1, "
        "'{\"accounts\":[{\"googleAccountKey\":\"home\",\"sources\":[]}]}')",
      );
      raw.execute(
        "INSERT INTO integrations (id, integration_type, enabled, config_json) "
        "VALUES ('$kDefaultPhotoPexelsIntegrationId', 'photo_pexels', 1, '{}')",
      );
      raw.execute('PRAGMA user_version = 9');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final googleLink = await db.customSelect(
      'SELECT account_id FROM integration_account_links '
      'WHERE integration_id = ?',
      variables: [Variable<String>(kDefaultCalendarGoogleIntegrationId)],
    ).getSingleOrNull();
    expect(googleLink, isNotNull);
    expect(googleLink!.read<String>('account_id'), 'home');

    final googleAccount = await db.customSelect(
      'SELECT account_type FROM integration_accounts WHERE id = ?',
      variables: [const Variable<String>('home')],
    ).getSingleOrNull();
    expect(googleAccount!.read<String>('account_type'), kIntegrationAccountTypeGoogle);

    final pexelsLink = await db.customSelect(
      'SELECT account_id FROM integration_account_links '
      'WHERE integration_id = ?',
      variables: [Variable<String>(kDefaultPhotoPexelsIntegrationId)],
    ).getSingleOrNull();
    expect(pexelsLink, isNotNull);
    expect(pexelsLink!.read<String>('account_id'), kDefaultPhotoPexelsIntegrationId);

    final pexelsAccount = await db.customSelect(
      'SELECT account_type FROM integration_accounts WHERE id = ?',
      variables: [Variable<String>(kDefaultPhotoPexelsIntegrationId)],
    ).getSingleOrNull();
    expect(
      pexelsAccount!.read<String>('account_type'),
      kIntegrationAccountTypeApiKeyPexels,
    );

    await db.close();
  });
}
