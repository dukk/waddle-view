import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/integration_accounts/integration_account_catalog.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 6 to 7 creates integration_accounts from config_json', () async {
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
      raw.execute(
        "INSERT INTO integrations (id, integration_type, enabled, config_json) "
        "VALUES ('$kDefaultCalendarGoogleIntegrationId', 'calendar_google', 1, "
        "'{\"accounts\":[{\"googleAccountKey\":\"home\",\"sources\":[]}]}')",
      );
      raw.execute(
        "INSERT INTO integrations (id, integration_type, enabled, config_json) "
        "VALUES ('$kDefaultPhotoOneDriveIntegrationId', 'photo_onedrive', 1, "
        "'{\"accounts\":[{\"graphAccountKey\":\"work\",\"sources\":[]}]}')",
      );
      raw.execute('PRAGMA user_version = 6');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final google = await db.customSelect(
      'SELECT id, account_type, label FROM integration_accounts WHERE id = ?',
      variables: [const Variable<String>('home')],
    ).getSingleOrNull();
    expect(google, isNotNull);
    expect(google!.read<String>('account_type'), kIntegrationAccountTypeGoogle);

    final microsoft = await db.customSelect(
      'SELECT id, account_type FROM integration_accounts WHERE id = ?',
      variables: [const Variable<String>('work')],
    ).getSingleOrNull();
    expect(microsoft, isNotNull);
    expect(
      microsoft!.read<String>('account_type'),
      kIntegrationAccountTypeMicrosoftGraph,
    );

    await db.close();
  });
}
