import { describe, it, expect, afterEach } from 'vitest';
import { createTestApp, sessionCookieHeader } from '../testHelpers.js';
import { setUserManagementEnabled } from '../services/settings.js';
import { upsertUserDisplay } from './userDisplays.js';

describe('users lifecycle', () => {
  let cleanup: (() => void) | undefined;

  afterEach(() => {
    cleanup?.();
    cleanup = undefined;
  });

  async function bootstrapAdmin(t: ReturnType<typeof createTestApp>) {
    setUserManagementEnabled(t.db, true);
    const boot = await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'passwordpassword' }),
    });
    return sessionCookieHeader(boot.headers.get('set-cookie') ?? undefined);
  }

  it('login updates lastLoginAt and returns mustChangePassword', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    await bootstrapAdmin(t);
    const loginAdmin = await t.app.request('/bff/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'passwordpassword' }),
    });
    const adminCookie = sessionCookieHeader(loginAdmin.headers.get('set-cookie') ?? undefined);
    const create = await t.app.request('/bff/v1/users', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(adminCookie ? { Cookie: adminCookie } : {}),
      },
      body: JSON.stringify({
        username: 'op1',
        password: 'passwordpassword',
        role: 'operator',
        mustChangePassword: true,
      }),
    });
    expect(create.status).toBe(201);
    const login = await t.app.request('/bff/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'op1', password: 'passwordpassword' }),
    });
    expect(login.status).toBe(200);
    const body = (await login.json()) as {
      user: { mustChangePassword: boolean };
    };
    expect(body.user.mustChangePassword).toBe(true);
    const list = await t.app.request('/bff/v1/users', {
      headers: adminCookie ? { Cookie: adminCookie } : {},
    });
    const users = (await list.json()) as {
      users: { username: string; lastLoginAt: string | null }[];
    };
    const op = users.users.find((u) => u.username === 'op1');
    expect(op?.lastLoginAt).toBeTruthy();
  });

  it('change-password clears mustChangePassword', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    const adminCookie = await bootstrapAdmin(t);
    await t.app.request('/bff/v1/users', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(adminCookie ? { Cookie: adminCookie } : {}),
      },
      body: JSON.stringify({
        username: 'op2',
        password: 'passwordpassword',
        role: 'operator',
        mustChangePassword: true,
      }),
    });
    const login = await t.app.request('/bff/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'op2', password: 'passwordpassword' }),
    });
    const opCookie = sessionCookieHeader(login.headers.get('set-cookie') ?? undefined);
    const change = await t.app.request('/bff/v1/auth/change-password', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(opCookie ? { Cookie: opCookie } : {}),
      },
      body: JSON.stringify({
        currentPassword: 'passwordpassword',
        newPassword: 'newpasswordpassword',
      }),
    });
    expect(change.status).toBe(200);
    const changed = (await change.json()) as { user: { mustChangePassword: boolean } };
    expect(changed.user.mustChangePassword).toBe(false);
    void adminCookie;
  });

  it('DELETE returns delete_failed code on errors', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    const adminCookie = await bootstrapAdmin(t);
    const headers = adminCookie ? { Cookie: adminCookie } : {};

    const notFound = await t.app.request('/bff/v1/users/missing-id', {
      method: 'DELETE',
      headers,
    });
    expect(notFound.status).toBe(404);
    expect((await notFound.json()) as { code: string }).toEqual({
      error: 'User not found',
      code: 'delete_failed',
    });

    const lastAdmin = await t.app.request('/bff/v1/users', { headers });
    const adminId = (
      (await lastAdmin.json()) as { users: { id: string; username: string }[] }
    ).users.find((u) => u.username === 'admin')!.id;
    const blocked = await t.app.request(`/bff/v1/users/${adminId}`, {
      method: 'DELETE',
      headers,
    });
    expect(blocked.status).toBe(400);
    expect((await blocked.json()) as { code: string }).toEqual({
      error: 'Cannot delete the last active admin',
      code: 'delete_failed',
    });
  });
});

describe('recovery export', () => {
  let cleanup: (() => void) | undefined;

  afterEach(() => {
    cleanup?.();
    cleanup = undefined;
  });

  it('exports displays when user mode is off', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    setUserManagementEnabled(t.db, true);
    const boot = await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'passwordpassword' }),
    });
    const bootBody = (await boot.json()) as { user: { id: string } };
    upsertUserDisplay(t.db, t.config.sessionSecret, bootBody.user.id, {
      displayId: 'd1',
      label: 'Kitchen',
      baseUrl: 'https://127.0.0.1:8787',
      clientIdentifier: 'wc-test',
      adoptedRole: 'operator',
      apiKey: 'test-api-key-value',
      permissions: ['screens.read'],
    });
    setUserManagementEnabled(t.db, false);
    const res = await t.app.request('/bff/v1/recovery/export-displays', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'passwordpassword' }),
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      displays: { id: string }[];
      sessions: Record<string, { apiKey: string }>;
    };
    expect(body.displays).toHaveLength(1);
    expect(body.sessions.d1?.apiKey).toBe('test-api-key-value');
  });

  it('rejects recovery when user mode is on', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    setUserManagementEnabled(t.db, true);
    await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'passwordpassword' }),
    });
    const res = await t.app.request('/bff/v1/recovery/export-displays', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'x', password: 'passwordpassword' }),
    });
    expect(res.status).toBe(403);
  });
});
