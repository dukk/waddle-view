import { describe, it, expect, afterEach } from 'vitest';
import { createTestApp } from './testHelpers.js';
import { setUserManagementEnabled } from './services/settings.js';

describe('needsBootstrap', () => {
  let cleanup: (() => void) | undefined;

  afterEach(() => {
    cleanup?.();
    cleanup = undefined;
  });

  it('is false when auth is disabled even if user management is on with no users', async () => {
    const t = createTestApp({ authEnabled: false });
    cleanup = t.cleanup;
    setUserManagementEnabled(t.db, true);
    const res = await t.app.request('/bff/v1/status');
    const body = (await res.json()) as {
      authEnabled: boolean;
      needsBootstrap: boolean;
    };
    expect(body.authEnabled).toBe(false);
    expect(body.needsBootstrap).toBe(false);
  });
});
