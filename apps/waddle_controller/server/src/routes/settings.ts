import { Hono } from 'hono';
import type { AppVariables } from '../middleware/context.js';
import { setUserManagementEnabled } from '../services/settings.js';
import { needsBootstrap } from '../services/bootstrap.js';
import { requireAdmin, requireAuth } from '../middleware/guards.js';

export function settingsRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();

  app.put('/settings', requireAuth, requireAdmin, async (c) => {
    const config = c.get('config');
    if (!config.authEnabled) {
      return c.json(
        {
          error: 'Enable WADDLE_CONTROLLER_AUTH_ENABLED on the server before user management',
          code: 'auth_disabled',
        },
        403,
      );
    }
    const body = (await c.req.json<{ userManagementEnabled?: boolean }>().catch(
      () => ({} as { userManagementEnabled?: boolean }),
    )) as { userManagementEnabled?: boolean };
    if (typeof body.userManagementEnabled !== 'boolean') {
      return c.json({ error: 'userManagementEnabled boolean required', code: 'invalid_request' }, 400);
    }
    const db = c.get('db');
    setUserManagementEnabled(db, body.userManagementEnabled);
    return c.json({
      userManagementEnabled: body.userManagementEnabled,
      needsBootstrap: needsBootstrap(db, config.authEnabled),
    });
  });

  return app;
}
