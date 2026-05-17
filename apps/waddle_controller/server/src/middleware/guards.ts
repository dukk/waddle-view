import { createMiddleware } from 'hono/factory';
import type { AppVariables } from './context.js';
import { needsBootstrap } from '../services/bootstrap.js';

const BOOTSTRAP_ALLOWED = new Set([
  'GET:/status',
  'POST:/bootstrap/admin',
]);

function routeKey(method: string, path: string): string {
  const normalized = path.replace(/\/+$/, '');
  const match = normalized.match(/\/bff\/v1(\/[^?]*)?/);
  const base = match?.[1] ?? '/';
  return `${method}:${base}`;
}

export const bootstrapGuard = createMiddleware<{ Variables: AppVariables }>(async (c, next) => {
  const db = c.get('db');
  if (!needsBootstrap(db, c.get('config').authEnabled)) {
    await next();
    return;
  }
  const key = routeKey(c.req.method, c.req.path);
  if (BOOTSTRAP_ALLOWED.has(key)) {
    await next();
    return;
  }
  return c.json({ error: 'Admin bootstrap required', code: 'needs_bootstrap' }, 409);
});

/** Routes that need a logged-in user (user_displays, etc.). */
export const requireAuthEnabled = createMiddleware<{ Variables: AppVariables }>(
  async (c, next) => {
    if (!c.get('config').authEnabled) {
      return c.json({ error: 'Authentication is disabled', code: 'auth_disabled' }, 403);
    }
    await next();
  },
);

export const requireAuth = createMiddleware<{ Variables: AppVariables }>(async (c, next) => {
  if (!c.get('config').authEnabled) {
    await next();
    return;
  }
  if (c.get('user')) {
    await next();
    return;
  }
  return c.json({ error: 'Unauthorized', code: 'unauthorized' }, 401);
});

export const requireAdmin = createMiddleware<{ Variables: AppVariables }>(async (c, next) => {
  const user = c.get('user');
  if (!c.get('config').authEnabled) {
    await next();
    return;
  }
  if (user?.role === 'admin') {
    await next();
    return;
  }
  return c.json({ error: 'Forbidden', code: 'forbidden' }, 403);
});

export const requireUserManagement = createMiddleware<{ Variables: AppVariables }>(async (c, next) => {
  if (!c.get('config').authEnabled) {
    return c.json({ error: 'Authentication is disabled', code: 'auth_disabled' }, 403);
  }
  const { isUserManagementEnabled } = await import('../services/settings.js');
  if (!isUserManagementEnabled(c.get('db'))) {
    return c.json({ error: 'User management is disabled', code: 'user_management_disabled' }, 403);
  }
  await next();
});
