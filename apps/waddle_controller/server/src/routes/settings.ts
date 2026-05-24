import { Hono } from 'hono';
import type { AppVariables } from '../middleware/context.js';
import { needsBootstrap } from '../services/bootstrap.js';
import { setUserModeEnabled } from '../services/userMode.js';
import { requireAdmin, requireAuth } from '../middleware/guards.js';

export function settingsRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();

  app.put('/settings', requireAuth, requireAdmin, async (c) => {
    const config = c.get('config');
    if (!config.authEnabled) {
      return c.json(
        {
          error: 'Enable WADDLE_CONTROLLER_AUTH_ENABLED on the server before user mode',
          code: 'auth_disabled',
        },
        403,
      );
    }
    const body = (await c.req.json<{ userModeEnabled?: boolean; userManagementEnabled?: boolean }>().catch(
      () => ({} as { userModeEnabled?: boolean; userManagementEnabled?: boolean }),
    )) as { userModeEnabled?: boolean; userManagementEnabled?: boolean };
    const enabled = body.userModeEnabled ?? body.userManagementEnabled;
    if (typeof enabled !== 'boolean') {
      return c.json(
        { error: 'userModeEnabled boolean required', code: 'invalid_request' },
        400,
      );
    }
    const db = c.get('db');
    await setUserModeEnabled(db, enabled);
    return c.json({
      userModeEnabled: enabled,
      userManagementEnabled: enabled,
      needsBootstrap: await needsBootstrap(db, config),
    });
  });

  return app;
}
