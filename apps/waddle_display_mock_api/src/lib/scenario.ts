import type { Context } from 'hono';

export type Scenario = 'default' | 'empty' | 'error' | 'unauthorized';

/** Query `?scenario=` wins, then header `X-Mock-Scenario`, then `default`. */
export function resolveScenario(c: Context): Scenario {
  const q = c.req.query('scenario')?.trim().toLowerCase();
  const h = c.req.header('x-mock-scenario')?.trim().toLowerCase();
  const raw = (q || h || 'default').toLowerCase();
  if (raw === 'empty' || raw === 'error' || raw === 'unauthorized') {
    return raw;
  }
  return 'default';
}

export function wantsError(scenario: Scenario): boolean {
  return scenario === 'error';
}

export function wantsEmpty(scenario: Scenario): boolean {
  return scenario === 'empty';
}

export function wantsUnauthorized(scenario: Scenario): boolean {
  return scenario === 'unauthorized';
}
