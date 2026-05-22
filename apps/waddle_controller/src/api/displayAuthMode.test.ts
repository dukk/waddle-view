import { describe, expect, it } from 'vitest';
import { isDisplayProxyAuthEnabled, setDisplayProxyAuthEnabled } from './displayAuthMode';

describe('displayAuthMode', () => {
  it('tracks display proxy auth flag', () => {
    setDisplayProxyAuthEnabled(true);
    expect(isDisplayProxyAuthEnabled()).toBe(true);
    setDisplayProxyAuthEnabled(false);
    expect(isDisplayProxyAuthEnabled()).toBe(false);
  });
});
