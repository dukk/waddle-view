import type { IntegrationRequiredAccountType } from './integrationAccounts';

export type IntegrationLinkedAccount = {
  account_id: string;
  account_type: string;
  account_type_label: string;
  label: string;
  signup_url?: string;
  supports_oauth_sign_in: boolean;
  configured: boolean;
  required: boolean;
};

export type IntegrationAccountsDetail = {
  required_account_types: IntegrationRequiredAccountType[];
  linked_accounts: IntegrationLinkedAccount[];
  accounts_configured: boolean;
};

export function integrationAccountsSatisfiedForEnable(
  detail: IntegrationAccountsDetail | null | undefined,
): boolean {
  if (!detail || detail.required_account_types.length === 0) {
    return true;
  }
  if (detail.linked_accounts.length === 0) {
    return false;
  }
  return detail.linked_accounts.every((a) => a.configured);
}

export function statusForRequiredAccountType(
  detail: IntegrationAccountsDetail,
  accountType: string,
): 'available' | 'pending' | 'missing' {
  const linked = detail.linked_accounts.filter((a) => a.account_type === accountType);
  if (linked.length === 0) {
    return 'missing';
  }
  if (linked.every((a) => a.configured)) {
    return 'available';
  }
  return 'pending';
}
