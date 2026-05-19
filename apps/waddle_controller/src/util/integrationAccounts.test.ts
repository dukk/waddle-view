import { describe, expect, it } from 'vitest';
import { defaultIntegrationAccountLabel } from './integrationAccounts';

describe('defaultIntegrationAccountLabel', () => {
  it('prefixes catalog labels that already end with account', () => {
    expect(defaultIntegrationAccountLabel('Google account')).toBe('My Google account');
    expect(defaultIntegrationAccountLabel('Microsoft account')).toBe('My Microsoft account');
  });

  it('prefixes api key and token catalog labels', () => {
    expect(defaultIntegrationAccountLabel('Pexels API key')).toBe('My Pexels API key');
    expect(defaultIntegrationAccountLabel('Home Assistant token')).toBe(
      'My Home Assistant token',
    );
  });

  it('appends account when the type label has no known suffix', () => {
    expect(defaultIntegrationAccountLabel('Custom provider')).toBe('My Custom provider account');
  });
});

describe('integrationAccounts types', () => {
  it('accepts a minimal account row shape', () => {
    const row = {
      id: 'home',
      account_type: 'google',
      account_type_label: 'Google account',
      label: 'home',
      configured: true,
      integration_types: ['calendar_google'],
    };
    expect(row.integration_types).toContain('calendar_google');
  });
});
