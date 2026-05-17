import fs from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';
import type { AppConfig } from '../config.js';
import { runMigrations } from './migrate.js';

export type AppDatabase = Database.Database;

export function openDatabase(config: Pick<AppConfig, 'dataDir' | 'dbPath'>): AppDatabase {
  fs.mkdirSync(config.dataDir, { recursive: true });
  const db = new Database(config.dbPath);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  runMigrations(db);
  return db;
}

export function openTestDatabase(dir: string): AppDatabase {
  const dataDir = path.join(dir, 'data');
  fs.mkdirSync(dataDir, { recursive: true });
  return openDatabase({ dataDir, dbPath: path.join(dataDir, 'waddle_controller.db') });
}
