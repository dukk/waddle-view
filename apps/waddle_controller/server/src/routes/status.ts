import { Hono } from 'hono';
import type { AppVariables } from '../middleware/context.js';
import { needsBootstrap } from '../services/bootstrap.js';
import { isRecoveryExportAvailable, isUserModeEnabled } from '../services/userMode.js';
import type { StatusResponse } from '../types.js';

export function statusRoutes() {
  const app = new Hono<{ Variables: AppVariables }>();

  app.get('/status', async (c) => {
    const config = c.get('config');
    const db = c.get('db');
    const user = c.get('user');
    const userModeEnabled = await isUserModeEnabled(db);
    const body: StatusResponse = {
      authEnabled: config.authEnabled,
      userModeEnabled,
      userManagementEnabled: userModeEnabled,
      needsBootstrap: await needsBootstrap(db, config),
      recoveryExportAvailable: await isRecoveryExportAvailable(config, db),
    };
    if (config.clientIdentifier) {
      body.clientIdentifier = config.clientIdentifier;
    }
    if (user) {
      body.user = {
        id: user.id,
        username: user.username,
        role: user.role,
        mustChangePassword: user.mustChangePassword,
      };
    }
    return c.json(body);
  });

  return app;
}
