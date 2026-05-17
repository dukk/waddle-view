/// Current SQLite DDL for [overlays].
const String kEnsureOverlaysTableSql = '''
CREATE TABLE IF NOT EXISTS overlays (
  id TEXT NOT NULL PRIMARY KEY,
  overlay_type TEXT NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  config_json TEXT NOT NULL DEFAULT '{}',
  config_json_schema TEXT,
  example_config_json TEXT,
  repeat_annually INTEGER NOT NULL DEFAULT 1,
  year_exact INTEGER,
  start_month INTEGER NOT NULL,
  start_day INTEGER NOT NULL,
  end_month INTEGER,
  end_day INTEGER,
  nth_week_of_month INTEGER,
  nth_weekday INTEGER,
  CHECK (repeat_annually IN (0, 1))
);
''';

/// Legacy DDL kept for reference only (pre schema v1 reset).
const String kLegacyEnsureDisplayOverlaySchedulesTableSql = '''
CREATE TABLE IF NOT EXISTS display_overlay_schedules (
  id TEXT NOT NULL PRIMARY KEY,
  enabled INTEGER NOT NULL DEFAULT 1,
  overlay_kind TEXT NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  messages_json TEXT NOT NULL DEFAULT '[]',
  config_json TEXT NOT NULL DEFAULT '{}',
  config_json_schema TEXT,
  example_config_json TEXT,
  repeat_annually INTEGER NOT NULL DEFAULT 1,
  year_exact INTEGER,
  start_month INTEGER NOT NULL,
  start_day INTEGER NOT NULL,
  end_month INTEGER,
  end_day INTEGER,
  nth_week_of_month INTEGER,
  nth_weekday INTEGER,
  CHECK (enabled IN (0, 1)),
  CHECK (repeat_annually IN (0, 1))
);
''';
