import { describe, it, expect, afterEach } from 'vitest';
import { createTestApp } from '../testHelpers.js';
import { createUser } from './users.js';
import { upsertUserDisplay } from './userDisplays.js';
import {
  resolveProxyTarget,
  upstreamPathFromProxyRequest,
} from './displayProxy.js';
import { DISPLAY_ID_HEADER, DISPLAY_URL_HEADER } from '../constants/proxyHeaders.js';

describe('displayProxy', () => {
  let cleanup: (() => void) | undefined;

  afterEach(() => {
    cleanup?.();
    cleanup = undefined;
  });

  it('maps proxy pathname to display path', () => {
    expect(upstreamPathFromProxyRequest('/bff/v1/proxy/v1/screens')).toBe('/v1/screens');
    expect(upstreamPathFromProxyRequest('/proxy/v1/adoption/request')).toBe('/v1/adoption/request');
  });

  it('resolves adoption target without auth', () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;
    const headers = new Headers({ [DISPLAY_URL_HEADER]: 'https://127.0.0.1:8787' });
    const result = resolveProxyTarget(
      t.config,
      t.db,
      null,
      '/v1/adoption/request',
      headers,
    );
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.upstreamUrl).toBe('https://127.0.0.1:8787');
    }
  });

  it('requires display URL for adoption paths', () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;
    const headers = new Headers();
    const result = resolveProxyTarget(
      t.config,
      t.db,
      null,
      '/v1/adoption/request',
      headers,
    );
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.code).toBe('display_url_required');
    }
  });

  it('resolves active display for authenticated users without URL header', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    const admin = await createUser(t.db, {
      username: 'admin',
      password: 'test-password1',
      role: 'admin',
    });
    upsertUserDisplay(t.db, t.config.sessionSecret, admin.id, {
      displayId: 'd_active',
      label: 'Kiosk',
      baseUrl: 'https://kiosk.test:8787',
      clientIdentifier: 'wc',
      adoptedRole: 'admin',
      apiKey: 'secret',
      permissions: [],
    });
    const { setActiveUserDisplay } = await import('./userDisplays.js');
    setActiveUserDisplay(t.db, admin.id, 'd_active');
    const headers = new Headers({ [DISPLAY_ID_HEADER]: 'd_active' });
    const result = resolveProxyTarget(
      t.config,
      t.db,
      admin,
      '/v1/screens',
      headers,
    );
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.upstreamUrl).toBe('https://kiosk.test:8787');
      expect(result.authorization).toMatch(/^Bearer /);
    }
  });

  it('rejects URL mismatch for registered display', async () => {
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
      adoptedRole: 'admin',
      apiKey: 'key',
      permissions: [],
    });
    const headers = new Headers({
      [DISPLAY_URL_HEADER]: 'http://evil.test',
      [DISPLAY_ID_HEADER]: 'd_one',
    });
    const result = resolveProxyTarget(t.config, t.db, admin, '/v1/screens', headers);
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.code).toBe('display_url_mismatch');
    }
  });
});
