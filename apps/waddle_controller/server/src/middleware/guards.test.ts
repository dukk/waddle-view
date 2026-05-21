import { describe, it, expect, afterEach } from 'vitest';
import { isAllowedDuringBootstrap } from './guards.js';
import { createTestApp, sessionCookieHeader } from '../testHelpers.js';
import { setUserManagementEnabled } from '../services/settings.js';

describe('requireAuth / requireAdmin', () => {
  let cleanup: (() => void) | undefined;

  afterEach(() => {
    cleanup?.();
    cleanup = undefined;
  });

  it('returns 401 for unauthenticated PUT /settings when auth is on but user mode is off', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    setUserManagementEnabled(t.db, true);
    await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'passwordpassword' }),
    });
    setUserManagementEnabled(t.db, false);
    const res = await t.app.request('/bff/v1/settings', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userModeEnabled: true }),
    });
    expect(res.status).toBe(401);
  });

  it('allows admin PUT /settings when auth is on and user mode is off', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    setUserManagementEnabled(t.db, true);
    const boot = await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'passwordpassword' }),
    });
    const cookie = sessionCookieHeader(boot.headers.get('set-cookie') ?? undefined);
    setUserManagementEnabled(t.db, false);
    const res = await t.app.request('/bff/v1/settings', {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...(cookie ? { Cookie: cookie } : {}),
      },
      body: JSON.stringify({ userModeEnabled: true }),
    });
    expect(res.status).toBe(200);
  });
});

describe('isAllowedDuringBootstrap', () => {
  it('allows status and bootstrap admin routes', () => {
    expect(isAllowedDuringBootstrap('GET', '/bff/v1/status')).toBe(true);
    expect(isAllowedDuringBootstrap('POST', '/bff/v1/bootstrap/admin')).toBe(true);
  });

  it('allows display adoption proxy paths', () => {
    expect(
      isAllowedDuringBootstrap('POST', '/bff/v1/proxy/v1/adoption/request'),
    ).toBe(true);
    expect(
      isAllowedDuringBootstrap('POST', '/bff/v1/proxy/v1/adoption/confirm'),
    ).toBe(true);
  });

  it('blocks other BFF routes during bootstrap', () => {
    expect(isAllowedDuringBootstrap('POST', '/bff/v1/auth/login')).toBe(false);
    expect(isAllowedDuringBootstrap('GET', '/bff/v1/proxy/v1/screens')).toBe(false);
  });
});
