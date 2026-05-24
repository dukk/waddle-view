import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import type Database from 'better-sqlite3';
import type { DbClient, DbDialect } from './client.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function migrationsDir(dialect: DbDialect): string {
  return path.join(__dirname, 'migrations', dialect);
}

function listMigrationFiles(dialect: DbDialect): string[] {
  const dir = migrationsDir(dialect);
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((name) => /^\d+_.+\.sql$/.test(name))
    .sort((a, b) => a.localeCompare(b));
}

function migrationVersion(filename: string): number {
  const match = /^(\d+)_/.exec(filename);
  if (!match) throw new Error(`Invalid migration filename: ${filename}`);
  return Number.parseInt(match[1]!, 10);
}

function readMigrationSql(dialect: DbDialect, filename: string): string {
  return fs.readFileSync(path.join(migrationsDir(dialect), filename), 'utf8');
}

function splitSqlStatements(sql: string): string[] {
  return sql
    .split(';')
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && !s.startsWith('--'));
}

function appliedVersionsSync(db: Database.Database): Set<number> {
  try {
    const rows = db.prepare('SELECT version FROM schema_migrations ORDER BY version').all() as {
      version: number;
    }[];
    return new Set(rows.map((r) => Number(r.version)));
  } catch {
    return new Set();
  }
}

function runSqlFileSync(db: Database.Database, sql: string): void {
  for (const statement of splitSqlStatements(sql)) {
    db.exec(`${statement};`);
  }
}

function columnExists(db: Database.Database, table: string, column: string): boolean {
  const rows = db.prepare(`PRAGMA table_info(${table})`).all() as { name: string }[];
  return rows.some((r) => r.name === column);
}

function migrateLegacySqliteColumns(db: Database.Database): void {
  if (!columnExists(db, 'users', 'must_change_password')) {
    db.exec('ALTER TABLE users ADD COLUMN must_change_password INTEGER NOT NULL DEFAULT 0');
  }
  if (!columnExists(db, 'users', 'last_login_at')) {
    db.exec('ALTER TABLE users ADD COLUMN last_login_at TEXT');
  }
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

function runVersionedSqliteMigrations(db: Database.Database): void {
  const applied = appliedVersionsSync(db);
  for (const file of listMigrationFiles('sqlite')) {
    const version = migrationVersion(file);
    if (applied.has(version)) continue;
    runSqlFileSync(db, readMigrationSql('sqlite', file));
    const now = new Date().toISOString();
    db.prepare('INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)').run(
      version,
      now,
    );
  }
}

/** Sync SQLite migrations for better-sqlite3 startup. */
export function runMigrations(db: Database.Database): void {
  const hasUsers = db
    .prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='users'")
    .get() as { name: string } | undefined;
  const hasSchemaMigrations = db
    .prepare(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='schema_migrations'",
    )
    .get() as { name: string } | undefined;

  if (hasUsers && !hasSchemaMigrations) {
    migrateLegacySqliteColumns(db);
    backfillBackupTargetSchedules(db);
  }

  runVersionedSqliteMigrations(db);
}

async function appliedVersions(db: DbClient): Promise<Set<number>> {
  try {
    const rows = await db.query<{ version: number }>(
      'SELECT version FROM schema_migrations ORDER BY version',
    );
    return new Set(rows.map((r) => Number(r.version)));
  } catch {
    return new Set();
  }
}

async function runSqlFile(db: DbClient, sql: string): Promise<void> {
  for (const statement of splitSqlStatements(sql)) {
    await db.exec(`${statement};`);
  }
}

export async function runMigrationsAsync(db: DbClient): Promise<void> {
  const applied = await appliedVersions(db);
  for (const file of listMigrationFiles(db.dialect)) {
    const version = migrationVersion(file);
    if (applied.has(version)) continue;
    await runSqlFile(db, readMigrationSql(db.dialect, file));
    const now = new Date().toISOString();
    await db.run('INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)', [
      version,
      now,
    ]);
  }
}
