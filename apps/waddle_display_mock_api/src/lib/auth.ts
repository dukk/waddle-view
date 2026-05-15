import type { Context } from 'hono';
import { createMiddleware } from 'hono/factory';
import { wantsUnauthorized } from './scenario.js';

function readExpectedKey(): string {
  const v = process.env.MOCK_API_KEY?.trim();
  return v && v.length > 0 ? v : 'dev-mock-key';
}

function presentedKey(c: Context): string {
  const h = c.req.header('x-api-key')?.trim() ?? '';
  const auth = c.req.header('authorization')?.trim() ?? '';
  if (auth.toLowerCase().startsWith('bearer ')) {
    return auth.slice(7).trim();
  }
  return h;
}

/** Public paths (no API key). */
function isPublicPath(path: string): boolean {
  return (
    path === '/' ||
    path === '/v1/health' ||
    path === 'v1/health'
  );
}

export const mockAuth = createMiddleware(async (c, next) => {
  if (c.req.method === 'OPTIONS') {
    return next();
  }
  if (wantsUnauthorized(c.get('scenario'))) {
    return c.json({ error: 'unauthorized' }, 401);
  }
  if (process.env.MOCK_SKIP_AUTH === '1') {
    return next();
  }
  if (isPublicPath(c.req.path)) {
    return next();
  }
  const expected = readExpectedKey();
  const got = presentedKey(c);
  if (!got || got !== expected) {
    return c.json({ error: 'unauthorized' }, 401);
  }
  return next();
});

export { readExpectedKey };
