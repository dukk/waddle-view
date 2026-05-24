#!/usr/bin/env node
import fs from 'node:fs';
import { loadConfig } from '../config.js';
import { openRawSqliteDatabase } from '../db/database.js';
import { createPostgresPool, PostgresDbClient } from '../db/postgresClient.js';
import { runMigrationsAsync } from '../db/migrate.js';

const TABLE_ORDER = [
  'settings',
  'users',
  'sessions',
  'user_displays',
  'backup_targets',
  'backup_snapshots',
] as const;

const BOOLEAN_COLUMNS: Record<string, string[]> = {
  users: ['disabled', 'must_change_password'],
  user_displays: ['is_active'],
  backup_targets: ['enabled'],
};

type CliOptions = {
  fromPath: string;
  toUrl: string;
  dryRun: boolean;
  force: boolean;
};

function parseArgs(argv: string[]): CliOptions {
  let fromPath: string | null = null;
  let toUrl = process.env.WADDLE_CONTROLLER_DATABASE_URL?.trim() || '';
  let dryRun = false;
  let force = false;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i]!;
    if (arg === '--from') {
      fromPath = argv[++i]?.trim() ?? '';
    } else if (arg === '--to') {
      toUrl = argv[++i]?.trim() ?? '';
    } else if (arg === '--dry-run') {
      dryRun = true;
    } else if (arg === '--force') {
      force = true;
    } else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    }
  }
  if (!fromPath) {
    const config = loadConfig();
    fromPath = config.dbPath;
  }
  if (!toUrl) {
    throw new Error('Target Postgres URL required via --to or WADDLE_CONTROLLER_DATABASE_URL');
  }
  if (!fs.existsSync(fromPath)) {
    throw new Error(`SQLite file not found: ${fromPath}`);
  }
  return { fromPath, toUrl, dryRun, force };
}

function printHelp(): void {
  console.log(`Usage: npm run db:migrate-to-postgres -- [options]

Options:
  --from <path>   Source SQLite file (default: WADDLE_CONTROLLER_DATA_DIR/waddle_controller.db)
  --to <url>      Target Postgres URL (default: WADDLE_CONTROLLER_DATABASE_URL)
  --dry-run       Compare row counts only; do not write
  --force         Allow copying into a Postgres database that already has rows
`);
}

function mapRowForPostgres(table: string, row: Record<string, unknown>): Record<string, unknown> {
  const boolCols = BOOLEAN_COLUMNS[table] ?? [];
  const mapped = { ...row };
  for (const col of boolCols) {
    if (col in mapped) {
      const value = mapped[col];
      mapped[col] = value === 1 || value === true;
    }
  }
  return mapped;
}

async function countRows(db: { query: (sql: string) => Promise<{ c: number }[]> }, table: string) {
  const rows = await db.query(`SELECT COUNT(*) AS c FROM ${table}`);
  return rows[0]?.c ?? 0;
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const sqlite = openRawSqliteDatabase(options.fromPath, true);

  const pool = createPostgresPool(options.toUrl);
  const postgres = new PostgresDbClient(pool);

  try {
    if (!options.dryRun) {
      await runMigrationsAsync(postgres);
    }

    const existingTotal = await postgres.query<{ c: number }>(
      `SELECT (
        (SELECT COUNT(*) FROM settings) +
        (SELECT COUNT(*) FROM users) +
        (SELECT COUNT(*) FROM sessions) +
        (SELECT COUNT(*) FROM user_displays) +
        (SELECT COUNT(*) FROM backup_targets) +
        (SELECT COUNT(*) FROM backup_snapshots)
      ) AS c`,
    );
    const targetRows = existingTotal[0]?.c ?? 0;
    if (targetRows > 0 && !options.force && !options.dryRun) {
      throw new Error(
        'Target Postgres database is not empty. Re-run with --force to overwrite copied tables.',
      );
    }

    if (!options.dryRun && (options.force || targetRows === 0)) {
      await postgres.exec(
        'TRUNCATE TABLE backup_snapshots, backup_targets, user_displays, sessions, users, settings RESTART IDENTITY CASCADE',
      );
    }

    const summary: { table: string; source: number; copied: number }[] = [];

    for (const table of TABLE_ORDER) {
      const sourceRows = sqlite.prepare(`SELECT * FROM ${table}`).all() as Record<
        string,
        unknown
      >[];
      summary.push({ table, source: sourceRows.length, copied: 0 });

      if (sourceRows.length === 0) continue;

      if (options.dryRun) continue;

      for (const row of sourceRows) {
        const mapped = mapRowForPostgres(table, row);
        const columns = Object.keys(mapped);
        const placeholders = columns.map(() => '?').join(', ');
        const values = columns.map((col) => mapped[col]);
        await postgres.run(
          `INSERT INTO ${table} (${columns.join(', ')}) VALUES (${placeholders})`,
          values,
        );
      }
      summary[summary.length - 1]!.copied = sourceRows.length;
    }

    console.log('SQLite → Postgres migration summary:');
    for (const row of summary) {
      const targetCount = options.dryRun
        ? row.source
        : await countRows(postgres, row.table);
      const ok = targetCount === row.source ? 'ok' : 'MISMATCH';
      console.log(
        `  ${row.table}: source=${row.source} target=${targetCount} copied=${row.copied} ${ok}`,
      );
      if (!options.dryRun && targetCount !== row.source) {
        process.exitCode = 1;
      }
    }

    if (options.dryRun) {
      console.log('Dry run complete — no data written.');
    } else {
      console.log('Migration complete.');
    }
  } finally {
    sqlite.close();
    await postgres.close();
  }
}

void main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
