export type DbDialect = 'sqlite' | 'postgres';

export type RunResult = {
  changes: number;
};

export interface DbClient {
  readonly dialect: DbDialect;
  query<T extends Record<string, unknown>>(sql: string, params?: unknown[]): Promise<T[]>;
  queryOne<T extends Record<string, unknown>>(
    sql: string,
    params?: unknown[],
  ): Promise<T | undefined>;
  run(sql: string, params?: unknown[]): Promise<RunResult>;
  exec(sql: string): Promise<void>;
  transaction<T>(fn: (tx: DbClient) => Promise<T>): Promise<T>;
  close(): Promise<void>;
}

export function isUniqueConstraintError(error: unknown, dialect: DbDialect): boolean {
  if (!error || typeof error !== 'object') return false;
  if (dialect === 'sqlite') {
    return 'code' in error && (error as { code: string }).code === 'SQLITE_CONSTRAINT_UNIQUE';
  }
  return 'code' in error && (error as { code: string }).code === '23505';
}
