import { Hono } from 'hono';
import { setCookie } from 'hono/cookie';
import type { AppVariables } from '../middleware/context.js';
import { needsBootstrap } from '../services/bootstrap.js';
import { createUser } from '../services/users.js';
import { createSession, SESSION_COOKIE, sessionCookieOptions } from '../services/sessions.js';
import { checkRateLimit } from '../lib/rateLimit.js';

export function bootstrapRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();

  app.post('/bootstrap/admin', async (c) => {
    const db = c.get('db');
    if (!needsBootstrap(db, c.get('config').authEnabled)) {
      return c.json({ error: 'Bootstrap not required', code: 'bootstrap_not_required' }, 409);
    }
    const ip = c.req.header('x-forwarded-for')?.split(',')[0]?.trim() || 'local';
    if (!checkRateLimit(`bootstrap:${ip}`)) {
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
    try {
      const user = await createUser(db, { username, password, role: 'admin' });
      const sessionId = createSession(db, user.id);
      setCookie(c, SESSION_COOKIE, sessionId, sessionCookieOptions(c.get('config')));
      return c.json({
        user: { id: user.id, username: user.username, role: user.role },
        needsBootstrap: false,
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Bootstrap failed';
      return c.json({ error: msg, code: 'bootstrap_failed' }, 400);
    }
  });

  return app;
}
