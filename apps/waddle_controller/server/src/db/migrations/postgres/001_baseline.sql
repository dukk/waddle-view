CREATE TABLE IF NOT EXISTS schema_migrations (
  version INTEGER PRIMARY KEY NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY NOT NULL,
  username TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'operator')),
  disabled BOOLEAN NOT NULL DEFAULT FALSE,
  must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS users_username_lower ON users (LOWER(username));

CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS sessions_user_id ON sessions (user_id);

CREATE TABLE IF NOT EXISTS user_displays (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  display_id TEXT NOT NULL,
  label TEXT NOT NULL,
  base_url TEXT NOT NULL,
  client_identifier TEXT NOT NULL,
  adopted_role TEXT NOT NULL,
  api_key_ciphertext TEXT NOT NULL,
  api_key_iv TEXT NOT NULL,
  permissions_json TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  UNIQUE (user_id, display_id)
);

CREATE INDEX IF NOT EXISTS user_displays_user_id ON user_displays (user_id);

CREATE TABLE IF NOT EXISTS backup_targets (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
  display_id TEXT NOT NULL,
  label TEXT NOT NULL,
  base_url TEXT NOT NULL,
  api_key_ciphertext TEXT NOT NULL,
  api_key_iv TEXT NOT NULL,
  cron_expr TEXT NOT NULL DEFAULT '0 2 * * *',
  schedule_frequency TEXT NOT NULL DEFAULT 'weekly',
  schedule_interval INTEGER NOT NULL DEFAULT 1,
  schedule_day_of_week INTEGER,
  schedule_hour INTEGER NOT NULL DEFAULT 2,
  schedule_minute INTEGER NOT NULL DEFAULT 0,
  timezone TEXT NOT NULL DEFAULT 'UTC',
  retention_count INTEGER NOT NULL DEFAULT 3,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  last_run_at TIMESTAMPTZ,
  last_status TEXT,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS backup_targets_user_id ON backup_targets (user_id);
CREATE INDEX IF NOT EXISTS backup_targets_display_id ON backup_targets (display_id);

CREATE TABLE IF NOT EXISTS backup_snapshots (
  id TEXT PRIMARY KEY NOT NULL,
  target_id TEXT NOT NULL REFERENCES backup_targets(id) ON DELETE CASCADE,
  display_id TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_name TEXT NOT NULL,
  byte_size BIGINT NOT NULL,
  manifest_json TEXT,
  source TEXT NOT NULL CHECK (source IN ('scheduled', 'manual', 'upload')),
  created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS backup_snapshots_target_id ON backup_snapshots (target_id);
