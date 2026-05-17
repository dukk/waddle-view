import { Hono } from 'hono';
import { deleteCookie, setCookie } from 'hono/cookie';
import type { AppVariables } from '../middleware/context.js';
import { findUserByUsername } from '../services/users.js';
import { verifyPassword } from '../services/password.js';
import {
  createSession,
  deleteSession,
  SESSION_COOKIE,
  sessionCookieOptions,
} from '../services/sessions.js';
import { checkRateLimit } from '../lib/rateLimit.js';
import { requireAuth } from '../middleware/guards.js';

export function authRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();

  app.post('/auth/login', async (c) => {
    const config = c.get('config');
    if (!config.authEnabled) {
      return c.json({ error: 'Authentication is disabled', code: 'auth_disabled' }, 403);
    }
    const ip = c.req.header('x-forwarded-for')?.split(',')[0]?.trim() || 'local';
    if (!checkRateLimit(`login:${ip}`)) {
      return c.json({ error: 'Too many attempts', code: 'rate_limited' }, 429);
    }
    const body = (await c.req.json<{ username?: string; password?: string }>().catch(
      () => ({} as { username?: string; password?: string }),
    )) as { username?: string; password?: string };
    const username = body.username?.trim() ?? '';
    const password = body.password ?? '';
    if (!username || !password) {
      return c.json({ error: 'Username and password required', code: 'invalid_request' }, 400);
    }
    const record = findUserByUsername(c.get('db'), username);
    if (!record || record.disabled) {
      return c.json({ error: 'Invalid credentials', code: 'invalid_credentials' }, 401);
    }
    const ok = await verifyPassword(password, record.passwordHash);
    if (!ok) {
      return c.json({ error: 'Invalid credentials', code: 'invalid_credentials' }, 401);
    }
    const sessionId = createSession(c.get('db'), record.id);
    setCookie(c, SESSION_COOKIE, sessionId, sessionCookieOptions(config));
    return c.json({
      user: { id: record.id, username: record.username, role: record.role },
    });
  });

  app.post('/auth/logout', requireAuth, (c) => {
    const sessionId = c.get('sessionId');
    if (sessionId) deleteSession(c.get('db'), sessionId);
    deleteCookie(c, SESSION_COOKIE, { path: '/' });
    return c.json({ ok: true });
  });

  app.get('/auth/me', requireAuth, (c) => {
    if (!c.get('config').authEnabled) {
      return c.json({ user: null });
    }
    const user = c.get('user');
    if (!user) return c.json({ error: 'Unauthorized', code: 'unauthorized' }, 401);
    return c.json({ user: { id: user.id, username: user.username, role: user.role } });
  });

  return app;
}
