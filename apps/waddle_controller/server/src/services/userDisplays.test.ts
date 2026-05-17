import { describe, it, expect, afterEach } from 'vitest';
import { createTestApp, sessionCookieHeader } from '../testHelpers.js';
import { setUserManagementEnabled } from './settings.js';
import { createUser } from './users.js';
import {
  findUserDisplayByDisplayId,
  listUserDisplays,
  setActiveUserDisplay,
  upsertUserDisplay,
} from './userDisplays.js';

describe('userDisplays', () => {
  let cleanup: (() => void) | undefined;

  afterEach(() => {
    cleanup?.();
    cleanup = undefined;
  });

  it('upserts and lists displays with encrypted keys', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    const admin = await createUser(t.db, {
      username: 'admin',
      password: 'secret-password',
      role: 'admin',
    });
    const row = upsertUserDisplay(t.db, t.config.sessionSecret, admin.id, {
      displayId: 'd_abc',
      label: 'Lobby',
      baseUrl: 'https://kiosk.local:8787',
      clientIdentifier: 'wc-host',
      adoptedRole: 'admin',
      apiKey: 'plain-api-key',
      permissions: ['telemetry.read'],
    });
    expect(row.hasApiKey).toBe(true);
    expect(row.adoptedRole).toBe('admin');
    const stored = findUserDisplayByDisplayId(t.db, admin.id, 'd_abc')!;
    expect(stored.api_key_ciphertext).not.toContain('plain-api-key');
    const list = listUserDisplays(t.db, admin.id);
    expect(list).toHaveLength(1);
    expect(list[0]!.displayId).toBe('d_abc');
  });

  it('sets a single active display', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    const admin = await createUser(t.db, {
      username: 'admin',
      password: 'test-password1',
      role: 'admin',
    });
    upsertUserDisplay(t.db, t.config.sessionSecret, admin.id, {
      displayId: 'd_one',
      label: 'One',
      baseUrl: 'https://127.0.0.1:8787',
      clientIdentifier: 'wc',
      adoptedRole: 'operator',
      apiKey: 'key1',
      permissions: [],
    });
    upsertUserDisplay(t.db, t.config.sessionSecret, admin.id, {
      displayId: 'd_two',
      label: 'Two',
      baseUrl: 'http://127.0.0.1:8788',
      clientIdentifier: 'wc',
      adoptedRole: 'viewer',
      apiKey: 'key2',
      permissions: [],
    });
    setActiveUserDisplay(t.db, admin.id, 'd_two');
    const list = listUserDisplays(t.db, admin.id);
    expect(list.find((d) => d.displayId === 'd_two')?.isActive).toBe(true);
    expect(list.find((d) => d.displayId === 'd_one')?.isActive).toBe(false);
  });

  it('exposes REST routes when authenticated', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    setUserManagementEnabled(t.db, true);
    const boot = await t.app.request('/bff/v1/bootstrap/admin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'ops', password: 'test-password1' }),
    });
    const cookie = sessionCookieHeader(boot.headers.get('set-cookie') ?? undefined);
    const put = await t.app.request('/bff/v1/user-displays', {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...(cookie ? { Cookie: cookie } : {}),
      },
      body: JSON.stringify({
        displayId: 'd_rest',
        label: 'REST',
        baseUrl: 'https://127.0.0.1:8787',
        clientIdentifier: 'wc',
        adoptedRole: 'admin',
        apiKey: 'rest-key',
        permissions: ['curator.read'],
      }),
    });
    expect(put.status).toBe(200);
    const list = await t.app.request('/bff/v1/user-displays', {
      headers: cookie ? { Cookie: cookie } : {},
    });
    expect(list.status).toBe(200);
    const body = (await list.json()) as { displays: { displayId: string }[] };
    expect(body.displays.some((d) => d.displayId === 'd_rest')).toBe(true);
  });
});
