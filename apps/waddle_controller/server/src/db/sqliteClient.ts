import type Database from 'better-sqlite3';
import type { DbClient, RunResult } from './client.js';

export class SqliteDbClient implements DbClient {
  readonly dialect = 'sqlite' as const;

  constructor(private readonly db: Database.Database) {}

  query<T extends Record<string, unknown>>(sql: string, params: unknown[] = []): Promise<T[]> {
    return Promise.resolve(this.db.prepare(sql).all(...params) as T[]);
  }

  queryOne<T extends Record<string, unknown>>(
    sql: string,
    params: unknown[] = [],
  ): Promise<T | undefined> {
    return Promise.resolve(this.db.prepare(sql).get(...params) as T | undefined);
  }

  run(sql: string, params: unknown[] = []): Promise<RunResult> {
    const result = this.db.prepare(sql).run(...params);
    return Promise.resolve({ changes: result.changes });
  }

  exec(sql: string): Promise<void> {
    this.db.exec(sql);
    return Promise.resolve();
  }

  async transaction<T>(fn: (tx: DbClient) => Promise<T>): Promise<T> {
    await this.exec('BEGIN');
    try {
      const result = await fn(this);
      await this.exec('COMMIT');
      return result;
    } catch (error) {
      await this.exec('ROLLBACK');
      throw error;
    }
  }

  close(): Promise<void> {
    this.db.close();
    return Promise.resolve();
  }

  /** Raw better-sqlite3 handle for legacy sync migration helpers during startup. */
  raw(): Database.Database {
    return this.db;
  }
}
