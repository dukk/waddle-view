import 'package:sqlite3/sqlite3.dart' as sqlite;

/// `onUpgrade` steps for schema ≥22 assume [calendar_events] exists before
/// `ALTER TABLE`, and steps ≥24 alter [blob_metadata]. Legacy migration tests
/// open a minimal DB at an old `user_version`; add these stubs so Drift can
/// reach the current schema.
void stubCalendarEventsAndBlobMetadataForMigration(sqlite.Database raw) {
  raw.execute('''
CREATE TABLE IF NOT EXISTS calendar_events (
  id TEXT NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  all_day INTEGER NOT NULL DEFAULT 0,
  location TEXT,
  description TEXT,
  source TEXT NOT NULL DEFAULT 'local',
  external_id TEXT,
  updated_at_ms INTEGER NOT NULL
);
''');
  raw.execute('''
CREATE TABLE IF NOT EXISTS blob_metadata (
  blob_key TEXT NOT NULL PRIMARY KEY,
  sha256 TEXT NOT NULL,
  relative_path TEXT NOT NULL,
  bytes INTEGER NOT NULL,
  mime_type TEXT,
  captured_at INTEGER NOT NULL
);
''');
}

/// When `user_version` is ≥19, migration `from < 19` is skipped, so
/// [content_categories] is never created but v22 adds a FK to it. Seed an empty
/// table so `ALTER TABLE calendar_events ADD COLUMN category_id` succeeds.
void stubContentCategoriesForMigration(sqlite.Database raw) {
  raw.execute('''
CREATE TABLE IF NOT EXISTS content_categories (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  icon_blob_key TEXT,
  material_icon_name TEXT
);
''');
}

/// Migration `from < 27` unconditionally reads the legacy `screen_definitions`
/// table (with `layout_json`/`data_key` columns) to rewrite it into the modern
/// `screen_type`/`config_json` shape. Tests that bootstrap a snapshot DB at any
/// `user_version` < 27 must seed this table or the migration will fail with
/// `no such table: screen_definitions`.
void stubLegacyScreenDefinitionsForMigration(sqlite.Database raw) {
  raw.execute('''
CREATE TABLE IF NOT EXISTS screen_definitions (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1,
  layout_json TEXT NOT NULL DEFAULT '{"v":1,"layout":"single","widgets":[]}',
  dwell_seconds INTEGER NOT NULL DEFAULT 10,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  min_gap_between_shows_seconds INTEGER NOT NULL DEFAULT 0,
  min_placements_per_program INTEGER NOT NULL DEFAULT 0,
  max_placements_per_program INTEGER,
  data_key TEXT NOT NULL DEFAULT ''
);
''');
}
