import type { DbDialect } from './client.js';

export function orderByUsername(dialect: DbDialect): string {
  return dialect === 'postgres' ? 'LOWER(username)' : 'username COLLATE NOCASE';
}

export function orderByLabel(dialect: DbDialect): string {
  return dialect === 'postgres' ? 'LOWER(label)' : 'label COLLATE NOCASE';
}

export function sqlBool(dialect: DbDialect, value: boolean): number | boolean {
  return dialect === 'postgres' ? value : value ? 1 : 0;
}

export function sqlActiveFlag(dialect: DbDialect): number | boolean {
  return sqlBool(dialect, true);
}

export function sqlInactiveFlag(dialect: DbDialect): number | boolean {
  return sqlBool(dialect, false);
}

export function usernameEquals(dialect: DbDialect): string {
  return dialect === 'postgres' ? 'LOWER(username) = LOWER(?)' : 'username = ? COLLATE NOCASE';
}
