import { describe, it, expect, afterEach, vi } from 'vitest';
import { createTestApp, sessionCookieHeader } from '../testHelpers.js';
import { setUserManagementEnabled } from '../services/settings.js';
import { DISPLAY_URL_HEADER } from '../constants/proxyHeaders.js';
import * as displayProxy from '../services/displayProxy.js';

describe('proxy routes', () => {
  let cleanup: (() => void) | undefined;

  afterEach(() => {
    cleanup?.();
    cleanup = undefined;
    vi.restoreAllMocks();
  });

  it('requires auth for normal API when auth enabled', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    setUserManagementEnabled(t.db, true);
    await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'test-password1' }),
    });
    const res = await t.app.request('/bff/v1/proxy/v1/screens', {
      headers: { [DISPLAY_URL_HEADER]: 'https://127.0.0.1:8787' },
    });
    expect(res.status).toBe(401);
  });

  it('forwards authenticated display API calls', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    setUserManagementEnabled(t.db, true);
    const boot = await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'test-password1' }),
    });
    const cookie = sessionCookieHeader(boot.headers.get('set-cookie') ?? undefined);
    const forward = vi.spyOn(displayProxy, 'forwardDisplayProxy').mockResolvedValue(
      new Response('[]', { status: 200, headers: { 'Content-Type': 'application/json' } }),
    );

    const res = await t.app.request('/bff/v1/proxy/v1/screens', {
      headers: {
        ...(cookie ? { Cookie: cookie } : {}),
        [DISPLAY_URL_HEADER]: 'https://127.0.0.1:8787',
      },
    });

    expect(res.status).toBe(200);
    expect(forward).toHaveBeenCalled();
  });
});
