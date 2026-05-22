import type Database from 'better-sqlite3';

const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY NOT NULL,
  username TEXT NOT NULL COLLATE NOCASE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'operator')),
  disabled INTEGER NOT NULL DEFAULT 0,
  must_change_password INTEGER NOT NULL DEFAULT 0,
  last_login_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS users_username ON users (username);

CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL
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
  is_active INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
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
  enabled INTEGER NOT NULL DEFAULT 1,
  last_run_at TEXT,
  last_status TEXT,
  last_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS backup_targets_user_id ON backup_targets (user_id);
CREATE INDEX IF NOT EXISTS backup_targets_display_id ON backup_targets (display_id);

CREATE TABLE IF NOT EXISTS backup_snapshots (
  id TEXT PRIMARY KEY NOT NULL,
  target_id TEXT NOT NULL REFERENCES backup_targets(id) ON DELETE CASCADE,
  display_id TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_name TEXT NOT NULL,
  byte_size INTEGER NOT NULL,
  manifest_json TEXT,
  source TEXT NOT NULL CHECK (source IN ('scheduled', 'manual', 'upload')),
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS backup_snapshots_target_id ON backup_snapshots (target_id);
`;

function columnExists(db: Database.Database, table: string, column: string): boolean {
  const rows = db.prepare(`PRAGMA table_info(${table})`).all() as { name: string }[];
  return rows.some((r) => r.name === column);
}

function migrateUsersColumns(db: Database.Database): void {
  if (!columnExists(db, 'users', 'must_change_password')) {
    db.exec(
      'ALTER TABLE users ADD COLUMN must_change_password INTEGER NOT NULL DEFAULT 0',
    );
  }
  if (!columnExists(db, 'users', 'last_login_at')) {
    db.exec('ALTER TABLE users ADD COLUMN last_login_at TEXT');
  }
}

function migrateBackupTargetScheduleColumns(db: Database.Database): void {
  if (!columnExists(db, 'backup_targets', 'schedule_frequency')) {
    db.exec(
      `ALTER TABLE backup_targets ADD COLUMN schedule_frequency TEXT NOT NULL DEFAULT 'weekly'`,
    );
  }
  if (!columnExists(db, 'backup_targets', 'schedule_interval')) {
    db.exec(`ALTER TABLE backup_targets ADD COLUMN schedule_interval INTEGER NOT NULL DEFAULT 1`);
  }
  if (!columnExists(db, 'backup_targets', 'schedule_day_of_week')) {
    db.exec(`ALTER TABLE backup_targets ADD COLUMN schedule_day_of_week INTEGER`);
  }
  if (!columnExists(db, 'backup_targets', 'schedule_hour')) {
    db.exec(`ALTER TABLE backup_targets ADD COLUMN schedule_hour INTEGER NOT NULL DEFAULT 2`);
  }
  if (!columnExists(db, 'backup_targets', 'schedule_minute')) {
    db.exec(`ALTER TABLE backup_targets ADD COLUMN schedule_minute INTEGER NOT NULL DEFAULT 0`);
  }
}

export function runMigrations(db: Database.Database): void {
  db.exec(SCHEMA_SQL);
  migrateUsersColumns(db);
  migrateBackupTargetScheduleColumns(db);
  backfillBackupTargetSchedules(db);
}

function parseCronForBackfill(cronExpr: string): {
  frequency: string;
  interval: number;
  dayOfWeek: number | null;
  hour: number;
  minute: number;
} | null {
  const parts = cronExpr.trim().split(/\s+/);
  if (parts.length !== 5) return null;
  const [minutePart, hourPart, dom, month, dow] = parts;
  if (dom !== '*' || month !== '*') return null;
  const minute = Number.parseInt(minutePart, 10);
  const hour = Number.parseInt(hourPart, 10);
  if (!Number.isFinite(minute) || !Number.isFinite(hour)) return null;
  if (dow === '*') {
    return { frequency: 'daily', interval: 1, dayOfWeek: null, hour, minute };
  }
  const dayOfWeek = Number.parseInt(dow, 10);
  if (!Number.isFinite(dayOfWeek) || dayOfWeek < 0 || dayOfWeek > 6) return null;
  return { frequency: 'weekly', interval: 1, dayOfWeek, hour, minute };
}

function backfillBackupTargetSchedules(db: Database.Database): void {
  if (!columnExists(db, 'backup_targets', 'schedule_frequency')) return;

  const rows = db.prepare('SELECT id, cron_expr FROM backup_targets').all() as {
    id: string;
    cron_expr: string;
  }[];

  const update = db.prepare(
    `UPDATE backup_targets SET
      schedule_frequency = ?,
      schedule_interval = ?,
      schedule_day_of_week = ?,
      schedule_hour = ?,
      schedule_minute = ?
     WHERE id = ?`,
  );

  for (const row of rows) {
    const parsed = parseCronForBackfill(row.cron_expr);
    if (!parsed) {
      const dow = Math.floor(Math.random() * 7);
      const hour = 2 + Math.floor(Math.random() * 3);
      const minute = Math.floor(Math.random() * 60);
      update.run('weekly', 1, dow, hour, minute, row.id);
      continue;
    }
    update.run(
      parsed.frequency,
      parsed.interval,
      parsed.dayOfWeek,
      parsed.hour,
      parsed.minute,
      row.id,
    );
  }
}
