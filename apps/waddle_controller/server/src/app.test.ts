import { describe, it, expect, afterEach } from 'vitest';
import { createTestApp, sessionCookieHeader } from './testHelpers.js';
import { setUserManagementEnabled } from './services/settings.js';
import type { StatusResponse } from './types.js';

describe('controller BFF', () => {
  let cleanup: (() => void) | undefined;

  afterEach(() => {
    cleanup?.();
    cleanup = undefined;
  });

  it('GET /bff/v1/status reflects auth and user management flags', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;
    const res = await t.app.request('/bff/v1/status');
    expect(res.status).toBe(200);
    const body = (await res.json()) as StatusResponse;
    expect(body.authEnabled).toBe(false);
    expect(body.userManagementEnabled).toBe(false);
    expect(body.needsBootstrap).toBe(false);
  });

  it('blocks routes with needs_bootstrap until admin is created', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    setUserManagementEnabled(t.db, true);
    const blocked = await t.app.request('/bff/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'a', password: 'passwordpassword' }),
    });
    expect(blocked.status).toBe(409);
    const bootstrap = await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'passwordpassword' }),
    });
    expect(bootstrap.status).toBe(200);
    const status = await t.app.request('/bff/v1/status');
    const statusBody = (await status.json()) as StatusResponse;
    expect(statusBody.needsBootstrap).toBe(false);
  });

  it('login and logout lifecycle', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    setUserManagementEnabled(t.db, true);
    const boot = await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'passwordpassword' }),
    });
    const bootCookie = sessionCookieHeader(boot.headers.get('set-cookie') ?? undefined);
    await t.app.request('/bff/v1/auth/logout', {
      method: 'POST',
      headers: bootCookie ? { Cookie: bootCookie } : {},
    });
    const login = await t.app.request('/bff/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'passwordpassword' }),
    });
    expect(login.status).toBe(200);
    const cookie = sessionCookieHeader(login.headers.get('set-cookie') ?? undefined);
    const me = await t.app.request('/bff/v1/auth/me', {
      headers: cookie ? { Cookie: cookie } : {},
    });
    expect(me.status).toBe(200);
    const meBody = (await me.json()) as { user: { username: string } };
    expect(meBody.user.username).toBe('admin');
  });

  it('rejects enabling user management when auth is disabled on server', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;
    const res = await t.app.request('/bff/v1/settings', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userManagementEnabled: true }),
    });
    expect(res.status).toBe(403);
  });

  it('admin can manage users when user management is enabled', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    setUserManagementEnabled(t.db, true);
    const boot = await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'passwordpassword' }),
    });
    const cookie = sessionCookieHeader(boot.headers.get('set-cookie') ?? undefined);
    const create = await t.app.request('/bff/v1/users', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(cookie ? { Cookie: cookie } : {}),
      },
      body: JSON.stringify({
        username: 'operator1',
        password: 'passwordpassword',
        role: 'operator',
      }),
    });
    expect(create.status).toBe(201);
    const list = await t.app.request('/bff/v1/users', {
      headers: cookie ? { Cookie: cookie } : {},
    });
    const listBody = (await list.json()) as { users: unknown[] };
    expect(listBody.users).toHaveLength(2);
  });

  it('requires auth when auth is enabled', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    const res = await t.app.request('/bff/v1/users');
    expect(res.status).toBe(401);
  });
});
