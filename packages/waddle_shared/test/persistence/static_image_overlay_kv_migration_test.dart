import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_repository.dart';
import 'package:waddle_shared/persistence/display_overlay_static_image_settings.dart';
import 'package:waddle_shared/persistence/tables.dart';

void main() {
  test('schema 30 to 31 migrates enabled display.image_overlay KV to static_image overlay', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE config_key_values (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
      raw.execute('''
CREATE TABLE overlays (
  id TEXT NOT NULL PRIMARY KEY,
  overlay_type TEXT NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  config_json TEXT NOT NULL DEFAULT '{}'
);
''');
      raw.execute('''
CREATE TABLE overlay_types (
  overlay_type TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  config_json_schema TEXT
);
''');
      raw.execute('''
CREATE TABLE curator_configurations (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  layer TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  program_duration_seconds INTEGER NOT NULL DEFAULT 180,
  history_depth INTEGER NOT NULL DEFAULT 5,
  require_news_photo_for_screens INTEGER NOT NULL DEFAULT 1,
  theme_id_override TEXT,
  default_config INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute('''
CREATE TABLE curator_configuration_members (
  configuration_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  PRIMARY KEY (configuration_id, entity_type, entity_id)
);
''');
      raw.execute(
        "INSERT INTO config_key_values (key, value) VALUES "
        "('display.image_overlay', "
        "'{\"enabled\":true,\"image_blob_key\":\"overlay/pool/duck_mascot\","
        "\"x\":0.9,\"y\":0.1,\"scale\":0.15,\"opacity\":0.5}')",
      );
      raw.execute(
        "INSERT INTO curator_configurations (id, name, layer) "
        "VALUES ('morning', 'Morning', 'base'), ('work', 'Work', 'base')",
      );
      raw.execute(
        "INSERT INTO curator_configurations (id, name, layer) "
        "VALUES ('bootstrap', 'Bootstrap', 'exclusive')",
      );
      raw.execute('PRAGMA user_version = 30');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final kv = await db.customSelect(
      "SELECT value FROM config_key_values WHERE key = 'display.image_overlay'",
    ).get();
    expect(kv, isEmpty);

    final rows = await fetchDisplayOverlays(db);
    final migrated = rows.singleWhere((r) => r.id == kMigratedDisplayImageOverlayId);
    expect(migrated.overlayType, kOverlayTypeStaticImage);
    final settings = StaticImageOverlaySettings.parse(migrated.configJson);
    expect(settings.imageBlobKey, kOverlayBlobKeyDuckMascot);
    expect(settings.x, 0.9);
    expect(settings.opacity, 0.5);

    final members = await db.customSelect(
      'SELECT configuration_id FROM curator_configuration_members '
      "WHERE entity_type = 'overlay' AND entity_id = ?",
      variables: [Variable<String>(kMigratedDisplayImageOverlayId)],
    ).get();
    expect(
      members.map((r) => r.read<String>('configuration_id')).toSet(),
      {'morning', 'work'},
    );

    await db.close();
  });

  test('schema 30 to 31 deletes disabled legacy KV without overlay row', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE config_key_values (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
      raw.execute(
        "INSERT INTO config_key_values (key, value) VALUES "
        "('display.image_overlay', '{\"enabled\":false}')",
      );
      raw.execute('PRAGMA user_version = 30');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final kv = await db.customSelect(
      "SELECT value FROM config_key_values WHERE key = 'display.image_overlay'",
    ).get();
    expect(kv, isEmpty);

    await db.close();
  });
}
