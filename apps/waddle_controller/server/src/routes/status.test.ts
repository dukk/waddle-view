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
});
