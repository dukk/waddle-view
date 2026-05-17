import { describe, it, expect, afterEach } from 'vitest';
import { createTestApp, sessionCookieHeader } from '../testHelpers.js';
import { setUserManagementEnabled } from '../services/settings.js';

describe('userDisplays routes', () => {
  let cleanup: (() => void) | undefined;

  afterEach(() => {
    cleanup?.();
    cleanup = undefined;
  });

  it('returns auth_disabled when controller auth is off', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;
    const res = await t.app.request('/bff/v1/user-displays', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        displayId: 'd_one',
        label: 'One',
        baseUrl: 'https://127.0.0.1:8787',
        clientIdentifier: 'wc',
        adoptedRole: 'admin',
        apiKey: 'secret-key',
        permissions: [],
      }),
    });
    expect(res.status).toBe(403);
    const body = (await res.json()) as { code?: string };
    expect(body.code).toBe('auth_disabled');
  });

  it('patches active display', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    setUserManagementEnabled(t.db, true);
    const boot = await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'test-password1' }),
    });
    const cookie = sessionCookieHeader(boot.headers.get('set-cookie') ?? undefined);
    await t.app.request('/bff/v1/user-displays', {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...(cookie ? { Cookie: cookie } : {}),
      },
      body: JSON.stringify({
        displayId: 'd_active',
        label: 'Active',
        baseUrl: 'https://127.0.0.1:8787',
        clientIdentifier: 'wc',
        adoptedRole: 'admin',
        apiKey: 'secret-key',
        permissions: [],
      }),
    });
    const patch = await t.app.request('/bff/v1/user-displays/active', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        ...(cookie ? { Cookie: cookie } : {}),
      },
      body: JSON.stringify({ displayId: 'd_active' }),
    });
    expect(patch.status).toBe(200);
    const body = (await patch.json()) as { display: { isActive: boolean } };
    expect(body.display.isActive).toBe(true);
  });

  it('deletes a saved display', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    setUserManagementEnabled(t.db, true);
    const boot = await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'test-password1' }),
    });
    const cookie = sessionCookieHeader(boot.headers.get('set-cookie') ?? undefined);
    await t.app.request('/bff/v1/user-displays', {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...(cookie ? { Cookie: cookie } : {}),
      },
      body: JSON.stringify({
        displayId: 'd_delete',
        label: 'Delete me',
        baseUrl: 'https://127.0.0.1:8787',
        clientIdentifier: 'wc',
        adoptedRole: 'viewer',
        apiKey: 'secret-key',
        permissions: [],
      }),
    });
    const del = await t.app.request('/bff/v1/user-displays/d_delete', {
      method: 'DELETE',
      headers: cookie ? { Cookie: cookie } : {},
    });
    expect(del.status).toBe(200);
  });
});
