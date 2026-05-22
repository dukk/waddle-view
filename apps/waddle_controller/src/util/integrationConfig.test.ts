import { describe, expect, it } from 'vitest';
import { integrationConfigBaseUrl } from './integrationConfig';

describe('integrationConfig', () => {
  it('integrationConfigBaseUrl reads trimmed baseUrl from config_json', () => {
    expect(integrationConfigBaseUrl({ baseUrl: ' https://example.com ' })).toBe(
      'https://example.com',
    );
    expect(integrationConfigBaseUrl({ baseUrl: '   ' })).toBeNull();
    expect(integrationConfigBaseUrl({})).toBeNull();
    expect(integrationConfigBaseUrl('not-json')).toBeNull();
  });
});
