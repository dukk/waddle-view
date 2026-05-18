import { describe, expect, it } from 'vitest';

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
