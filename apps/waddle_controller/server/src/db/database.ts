import fs from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';
import type { AppConfig } from '../config.js';
import type { DbClient } from './client.js';
import { runMigrations, runMigrationsAsync } from './migrate.js';
import { createPostgresPool, PostgresDbClient } from './postgresClient.js';
import { SqliteDbClient } from './sqliteClient.js';

export type AppDatabase = DbClient;

export function openDatabase(config: Pick<AppConfig, 'dataDir' | 'dbPath' | 'databaseUrl'>): AppDatabase {
  if (config.databaseUrl) {
    throw new Error(
      'openDatabase is sync; use openDatabaseAsync when WADDLE_CONTROLLER_DATABASE_URL is set',
    );
  }
  fs.mkdirSync(config.dataDir, { recursive: true });
  const db = new Database(config.dbPath);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  runMigrations(db);
  return new SqliteDbClient(db);
}

export async function openDatabaseAsync(
  config: Pick<AppConfig, 'dataDir' | 'dbPath' | 'databaseUrl'>,
): Promise<AppDatabase> {
  if (config.databaseUrl) {
    const pool = createPostgresPool(config.databaseUrl);
    const client = new PostgresDbClient(pool);
    await runMigrationsAsync(client);
    return client;
  }
  return openDatabase(config);
}

export function openTestDatabase(dir: string): AppDatabase {
  const dataDir = path.join(dir, 'data');
  fs.mkdirSync(dataDir, { recursive: true });
  return openDatabase({ dataDir, dbPath: path.join(dataDir, 'waddle_controller.db'), databaseUrl: null });
}

/** Opens a SQLite file for migration tooling (not wrapped in DbClient). */
export function openRawSqliteDatabase(dbPath: string, readonly = true): Database.Database {
  const db = new Database(dbPath, { readonly });
  db.pragma('foreign_keys = ON');
  return db;
}
