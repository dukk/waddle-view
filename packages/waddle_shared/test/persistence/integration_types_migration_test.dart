import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 5 to 6 renames integration types and default ids', () async {
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
CREATE TABLE integration_secrets (
  secret_key TEXT NOT NULL PRIMARY KEY,
  ciphertext BLOB NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
''');
      raw.execute(
        "INSERT INTO integration_secrets (secret_key, ciphertext, updated_at_ms) "
        "VALUES ('provider:access_token:media_pexels', X'010203', 1000)",
      );
      raw.execute(
        "INSERT INTO integrations (id, provider_type, enabled, config_json) "
        "VALUES ('media_pexels', 'media_pexels', 1, "
        "'{\"maxPhotos\":10,\"maxVideos\":5,\"photosPerHour\":1,\"videosPerHour\":1}')",
      );
      raw.execute(
        "INSERT INTO integrations (id, provider_type, enabled) "
        "VALUES ('weather_nws_alerts', 'weather_nws_alerts', 1)",
      );
      raw.execute('PRAGMA user_version = 5');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final photo = await db.customSelect(
      'SELECT id, integration_type FROM integrations WHERE id = ?',
      variables: [Variable<String>(kDefaultPhotoPexelsIntegrationId)],
    ).getSingleOrNull();
    expect(photo, isNotNull);
    expect(photo!.read<String>('integration_type'), 'photo_pexels');

    final video = await db.customSelect(
      'SELECT id, integration_type FROM integrations WHERE id = ?',
      variables: [Variable<String>(kDefaultVideoPexelsIntegrationId)],
    ).getSingleOrNull();
    expect(video, isNotNull);
    expect(video!.read<String>('integration_type'), 'video_pexels');

    final nws = await db.customSelect(
      'SELECT id, integration_type FROM integrations WHERE id = ?',
      variables: [Variable<String>(kDefaultWeatherAlertsNwsIntegrationId)],
    ).getSingle();
    expect(nws.read<String>('integration_type'), 'weather_alerts_nws');

    final photoSecret = await db.customSelect(
      'SELECT secret_key, ciphertext, updated_at_ms FROM integration_secrets '
      'WHERE secret_key = ?',
      variables: [
        Variable<String>(
          'provider:access_token:$kDefaultPhotoPexelsIntegrationId',
        ),
      ],
    ).getSingleOrNull();
    expect(photoSecret, isNotNull);
    expect(photoSecret!.read<Uint8List>('ciphertext'), [1, 2, 3]);
    expect(photoSecret.read<int>('updated_at_ms'), 1000);

    final videoSecret = await db.customSelect(
      'SELECT secret_key FROM integration_secrets WHERE secret_key = ?',
      variables: [
        Variable<String>(
          'provider:access_token:$kDefaultVideoPexelsIntegrationId',
        ),
      ],
    ).getSingleOrNull();
    expect(videoSecret, isNotNull);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);

    await db.close();
  });
}
