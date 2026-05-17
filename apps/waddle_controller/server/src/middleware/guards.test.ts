import { describe, it, expect } from 'vitest';
import { isAllowedDuringBootstrap } from './guards.js';

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
