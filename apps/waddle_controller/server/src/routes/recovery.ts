import { Hono } from 'hono';
import type { AppVariables } from '../middleware/context.js';
import { checkRateLimit } from '../lib/rateLimit.js';
import { findUserByUsername } from '../services/users.js';
import { verifyPassword } from '../services/password.js';
import { buildRecoveryExport } from '../services/recoveryExport.js';
import { isRecoveryExportAvailable } from '../services/userMode.js';

export function recoveryRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();

  app.post('/recovery/export-displays', async (c) => {
    const config = c.get('config');
    const db = c.get('db');
    if (!isRecoveryExportAvailable(config, db)) {
      return c.json(
        { error: 'Recovery export is not available', code: 'recovery_unavailable' },
        403,
      );
    }
    const ip = c.req.header('x-forwarded-for')?.split(',')[0]?.trim() || 'local';
    if (!checkRateLimit(`recovery:${ip}`)) {
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
    const record = findUserByUsername(db, username);
    if (!record || record.disabled) {
      return c.json({ error: 'Invalid credentials', code: 'invalid_credentials' }, 401);
    }
    const ok = await verifyPassword(password, record.passwordHash);
    if (!ok) {
      return c.json({ error: 'Invalid credentials', code: 'invalid_credentials' }, 401);
    }
    const payload = buildRecoveryExport(config, db, record.id);
    return c.json(payload);
  });

  return app;
}
