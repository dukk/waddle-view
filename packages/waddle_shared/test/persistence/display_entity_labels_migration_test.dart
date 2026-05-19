import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 23 to 24 renames name to label and pexels_page_url to page_url', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE screens (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  screen_type TEXT NOT NULL,
  config_json TEXT NOT NULL DEFAULT '{}',
  config_json_schema TEXT,
  example_config_json TEXT,
  min_dwell_seconds INTEGER NOT NULL DEFAULT 8,
  max_dwell_seconds INTEGER NOT NULL DEFAULT 15,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  min_gap_between_shows_seconds INTEGER NOT NULL DEFAULT 0,
  min_placements_per_program INTEGER NOT NULL DEFAULT 0,
  max_placements_per_program INTEGER,
  data_key TEXT NOT NULL DEFAULT ''
);
''');
      raw.execute('''
CREATE TABLE ticker_tapes (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  ticker_type TEXT NOT NULL,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  sort_order INTEGER NOT NULL DEFAULT 0,
  config_key TEXT,
  config_json TEXT NOT NULL DEFAULT '{}',
  config_json_schema TEXT,
  example_config_json TEXT
);
''');
      raw.execute('''
CREATE TABLE overlays (
  id TEXT NOT NULL PRIMARY KEY,
  overlay_type TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  config_json TEXT NOT NULL DEFAULT '{}',
  config_json_schema TEXT
);
''');
      raw.execute('''
CREATE TABLE photos (
  id TEXT NOT NULL PRIMARY KEY,
  category TEXT NOT NULL DEFAULT 'pexels',
  data_provider TEXT NOT NULL DEFAULT 'photo_pexels',
  media_blob_key TEXT NOT NULL,
  photographer_name TEXT NOT NULL,
  photographer_url TEXT NOT NULL,
  pexels_page_url TEXT NOT NULL,
  alt_text TEXT NOT NULL DEFAULT '',
  fetched_at_ms INTEGER NOT NULL,
  suppressed INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute(
        "INSERT INTO screens (id, name, screen_type) VALUES ('welcome', 'Welcome', 'static_text')",
      );
      raw.execute(
        "INSERT INTO ticker_tapes (id, name, ticker_type) VALUES ('ticker_time', 'Time', 'time')",
      );
      raw.execute(
        "INSERT INTO overlays (id, overlay_type, name, config_json) "
        "VALUES ('demo', 'shape_rain', 'Hearts', '{}')",
      );
      raw.execute(
        "INSERT INTO photos (id, media_blob_key, photographer_name, photographer_url, "
        "pexels_page_url, fetched_at_ms) "
        "VALUES ('p1', 'blob', 'Alice', 'https://alice.example', "
        "'https://pexels.com/p/1', 1)",
      );
      raw.execute('PRAGMA user_version = 23');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final screen = await db.customSelect(
      'SELECT label FROM screens WHERE id = ?',
      variables: [const Variable<String>('welcome')],
    ).getSingle();
    expect(screen.read<String>('label'), 'Welcome');

    final ticker = await db.customSelect(
      'SELECT label FROM ticker_tapes WHERE id = ?',
      variables: [const Variable<String>('ticker_time')],
    ).getSingle();
    expect(ticker.read<String>('label'), 'Time');

    final overlay = await db.customSelect(
      'SELECT label FROM overlays WHERE id = ?',
      variables: [const Variable<String>('demo')],
    ).getSingle();
    expect(overlay.read<String>('label'), 'Hearts');

    final photo = await db.customSelect(
      'SELECT page_url FROM photos WHERE id = ?',
      variables: [const Variable<String>('p1')],
    ).getSingle();
    expect(photo.read<String>('page_url'), 'https://pexels.com/p/1');

    await db.close();
  });
}
