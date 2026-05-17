import { describe, expect, it } from 'vitest';
import { integrationSecretsSatisfiedForEnable } from './integrationSecrets';

describe('integrationSecretsSatisfiedForEnable', () => {
  it('allows enable when there are no secret slots', () => {
    expect(integrationSecretsSatisfiedForEnable([], {})).toBe(true);
  });

  it('blocks when a required slot is neither configured nor drafted', () => {
    expect(
      integrationSecretsSatisfiedForEnable(
        [{ id: 'api_key', label: 'API key', configured: false }],
        {},
      ),
    ).toBe(false);
  });

  it('allows when slot is already configured', () => {
    expect(
      integrationSecretsSatisfiedForEnable(
        [{ id: 'api_key', label: 'API key', configured: true }],
        {},
      ),
    ).toBe(true);
  });

  it('allows when draft supplies a new value', () => {
    expect(
      integrationSecretsSatisfiedForEnable(
        [{ id: 'api_key', label: 'API key', configured: false }],
        { api_key: 'sk-new' },
      ),
    ).toBe(true);
  });
});
