import { describe, expect, it } from 'vitest';
import { resolveClientIdentifier } from './clientIdentifier';

describe('resolveClientIdentifier', () => {
  it('uses env value when configured', () => {
    const result = resolveClientIdentifier(
      { authEnabled: true, userManagementEnabled: true, needsBootstrap: false, clientIdentifier: 'wc-fixed' },
      'wc-fallback',
    );
    expect(result).toEqual({ value: 'wc-fixed', locked: true });
  });

  it('falls back when env unset', () => {
    const result = resolveClientIdentifier(
      { authEnabled: false, userManagementEnabled: false, needsBootstrap: false },
      'wc-fallback',
    );
    expect(result).toEqual({ value: 'wc-fallback', locked: false });
  });
});
