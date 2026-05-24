import { describe, it, expect, afterEach } from 'vitest';
import { createTestApp } from './testHelpers.js';
import { setUserManagementEnabled } from './services/settings.js';
import { DISPLAY_URL_HEADER } from './constants/proxyHeaders.js';
import type { StatusResponse } from './types.js';

describe('needsBootstrap and user mode', () => {
  let cleanup: (() => void | Promise<void>) | undefined;

  afterEach(async () => {
    await cleanup?.();
    cleanup = undefined;
  });

  it('is false when auth capability is disabled even if user mode flag is on', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;
    await setUserManagementEnabled(t.db, true);
    const res = await t.app.request('/bff/v1/status');
    const body = (await res.json()) as StatusResponse;
    expect(body.authEnabled).toBe(false);
    expect(body.needsBootstrap).toBe(false);
  });

  it('allows proxy with URL header when user mode is off', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    await setUserManagementEnabled(t.db, false);
    const res = await t.app.request('/bff/v1/proxy/v1/screens', {
      headers: { [DISPLAY_URL_HEADER]: 'http://127.0.0.1:1' },
    });
    expect(res.status).not.toBe(401);
  });

  it('reports recoveryExportAvailable when user mode off and displays exist', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    await setUserManagementEnabled(t.db, true);
    const boot = await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'passwordpassword' }),
    });
    const bootBody = (await boot.json()) as { user: { id: string } };
    const { upsertUserDisplay } = await import('./services/userDisplays.js');
    await upsertUserDisplay(t.db, t.config.sessionSecret, bootBody.user.id, {
      displayId: 'd1',
      label: 'X',
      baseUrl: 'https://127.0.0.1:8787',
      clientIdentifier: 'wc',
      adoptedRole: 'operator',
      apiKey: 'key1234567890',
      permissions: [],
    });
    await setUserManagementEnabled(t.db, false);
    const status = await t.app.request('/bff/v1/status');
    const body = (await status.json()) as StatusResponse;
    expect(body.recoveryExportAvailable).toBe(true);
    expect(body.userModeEnabled).toBe(false);
  });
});
