/** Rewrites `?` placeholders to `$1`, `$2`, … for PostgreSQL. */
export function toPostgresPlaceholders(sql: string): string {
  let index = 0;
  return sql.replace(/\?/g, () => `$${++index}`);
}
