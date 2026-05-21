import { describe, it, expect, afterEach } from 'vitest';
import { createTestApp } from '../testHelpers.js';

describe('status route', () => {
  let cleanup: (() => void) | undefined;

  afterEach(() => {
    cleanup?.();
    cleanup = undefined;
  });

  it('includes clientIdentifier from config', async () => {
    const t = createTestApp({ clientIdentifier: 'wc-deployed' });
    cleanup = t.cleanup;
    const res = await t.app.request('/bff/v1/status');
    const body = (await res.json()) as { clientIdentifier?: string };
    expect(body.clientIdentifier).toBe('wc-deployed');
  });

  it('includes userModeEnabled and recoveryExportAvailable', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    const res = await t.app.request('/bff/v1/status');
    const body = (await res.json()) as {
      userModeEnabled: boolean;
      userManagementEnabled: boolean;
      recoveryExportAvailable: boolean;
    };
    expect(body.userModeEnabled).toBe(body.userManagementEnabled);
    expect(body.recoveryExportAvailable).toBe(false);
  });
});
