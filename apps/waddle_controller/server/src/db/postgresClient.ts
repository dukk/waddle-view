import pg from 'pg';
import type { DbClient, RunResult } from './client.js';
import { toPostgresPlaceholders } from './sqlPlaceholders.js';

const { Pool } = pg;

export class PostgresDbClient implements DbClient {
  readonly dialect = 'postgres' as const;

  constructor(private readonly pool: pg.Pool) {}

  async query<T extends Record<string, unknown>>(
    sql: string,
    params: unknown[] = [],
  ): Promise<T[]> {
    const result = await this.pool.query<T>(toPostgresPlaceholders(sql), params);
    return result.rows;
  }

  async queryOne<T extends Record<string, unknown>>(
    sql: string,
    params: unknown[] = [],
  ): Promise<T | undefined> {
    const rows = await this.query<T>(sql, params);
    return rows[0];
  }

  async run(sql: string, params: unknown[] = []): Promise<RunResult> {
    const result = await this.pool.query(toPostgresPlaceholders(sql), params);
    return { changes: result.rowCount ?? 0 };
  }

  async exec(sql: string): Promise<void> {
    await this.pool.query(sql);
  }

  async transaction<T>(fn: (tx: DbClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    const txClient = new PostgresDbTransactionClient(client);
    try {
      await client.query('BEGIN');
      const result = await fn(txClient);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async close(): Promise<void> {
    await this.pool.end();
  }
}

class PostgresDbTransactionClient implements DbClient {
  readonly dialect = 'postgres' as const;

  constructor(private readonly client: pg.PoolClient) {}

  query<T extends Record<string, unknown>>(sql: string, params: unknown[] = []): Promise<T[]> {
    return this.client
      .query<T>(toPostgresPlaceholders(sql), params)
      .then((result) => result.rows);
  }

  queryOne<T extends Record<string, unknown>>(
    sql: string,
    params: unknown[] = [],
  ): Promise<T | undefined> {
    return this.query<T>(sql, params).then((rows) => rows[0]);
  }

  async run(sql: string, params: unknown[] = []): Promise<RunResult> {
    const result = await this.client.query(toPostgresPlaceholders(sql), params);
    return { changes: result.rowCount ?? 0 };
  }

  exec(sql: string): Promise<void> {
    return this.client.query(sql).then(() => undefined);
  }

  transaction<T>(fn: (tx: DbClient) => Promise<T>): Promise<T> {
    return fn(this);
  }

  close(): Promise<void> {
    return Promise.resolve();
  }
}

export function createPostgresPool(databaseUrl: string): pg.Pool {
  return new Pool({ connectionString: databaseUrl });
}
