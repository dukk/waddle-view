import { describe, it, expect, afterEach } from 'vitest';
import { createTestApp } from '../testHelpers.js';
import type { AboutResponse } from '../types.js';
import { resetAboutManifestCacheForTests } from '../services/aboutManifest.js';

describe('GET /bff/v1/about', () => {
  let cleanup: (() => void) | undefined;

  afterEach(() => {
    resetAboutManifestCacheForTests();
    cleanup?.();
    cleanup = undefined;
  });

  it('returns controller version and license metadata', async () => {
    const t = createTestApp();
    cleanup = t.cleanup;
    const res = await t.app.request('/bff/v1/about');
    expect(res.status).toBe(200);
    const body = (await res.json()) as AboutResponse;
    expect(body.app).toBe('waddle_controller');
    expect(body.version).toMatch(/^\d+\.\d+\.\d+/);
    expect(typeof body.build).toBe('string');
    expect(body.productLicense.id).toBe('ONC');
    expect(Array.isArray(body.dependencies)).toBe(true);
    expect(typeof body.thirdPartyNotices).toBe('string');
  });

  it('is allowed during bootstrap', async () => {
    const t = createTestApp({ authEnabled: true });
    cleanup = t.cleanup;
    const res = await t.app.request('/bff/v1/about');
    expect(res.status).toBe(200);
  });
});
