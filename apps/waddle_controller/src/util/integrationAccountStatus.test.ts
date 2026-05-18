import { describe, expect, it } from 'vitest';
import {
  integrationAccountsSatisfiedForEnable,
  statusForRequiredAccountType,
  type IntegrationAccountsDetail,
} from './integrationAccountStatus';

describe('integrationAccountStatus', () => {
  const baseDetail: IntegrationAccountsDetail = {
    required_account_types: [
      {
        account_type: 'google',
        account_type_label: 'Google account',
        signup_url: 'https://accounts.google.com/signup',
        supports_oauth_sign_in: true,
      },
    ],
    linked_accounts: [
      {
        account_id: 'home',
        account_type: 'google',
        account_type_label: 'Google account',
        label: 'home',
        supports_oauth_sign_in: true,
        configured: true,
        required: true,
      },
    ],
    accounts_configured: true,
  };

  it('treats empty requirements as satisfied', () => {
    expect(
      integrationAccountsSatisfiedForEnable({
        required_account_types: [],
        linked_accounts: [],
        accounts_configured: true,
      }),
    ).toBe(true);
  });

  it('requires all linked accounts configured', () => {
    expect(integrationAccountsSatisfiedForEnable(baseDetail)).toBe(true);
    expect(
      integrationAccountsSatisfiedForEnable({
        ...baseDetail,
        linked_accounts: [{ ...baseDetail.linked_accounts[0], configured: false }],
      }),
    ).toBe(false);
  });

  it('maps account type status', () => {
    expect(statusForRequiredAccountType(baseDetail, 'google')).toBe('available');
    expect(statusForRequiredAccountType(baseDetail, 'microsoft_graph')).toBe('missing');
  });
});
