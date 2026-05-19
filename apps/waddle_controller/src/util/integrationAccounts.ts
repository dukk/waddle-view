/** Default operator-facing name when adding a shared integration account. */
export function defaultIntegrationAccountLabel(accountTypeLabel: string): string {
  const trimmed = accountTypeLabel.trim();
  if (!trimmed) {
    return 'My account';
  }
  const lower = trimmed.toLowerCase();
  if (
    lower.endsWith(' account') ||
    lower.endsWith(' api key') ||
    lower.endsWith(' token')
  ) {
    return `My ${trimmed}`;
  }
  return `My ${trimmed} account`;
}

export type IntegrationAccountType = {
  id: string;
  label: string;
  signup_url?: string;
  supports_oauth_sign_in?: boolean;
  integration_types: string[];
};

export type IntegrationAccountRequirement = {
  integration_type: string;
  account_type: string;
  account_type_label: string;
  signup_url: string;
  supports_oauth_sign_in?: boolean;
};

export type OAuthSignInStatus = 'pending' | 'expired';

export type IntegrationAccountRow = {
  id: string;
  account_type: string;
  account_type_label: string;
  label: string;
  signup_url?: string;
  supports_oauth_sign_in?: boolean;
  configured: boolean;
  oauth_sign_in_status?: OAuthSignInStatus | null;
  integration_types: string[];
  integration_ids?: string[];
};

export type IntegrationAccountsResponse = {
  account_types: IntegrationAccountType[];
  requirements: IntegrationAccountRequirement[];
  items: IntegrationAccountRow[];
};

export type IntegrationRequiredAccountType = {
  account_type: string;
  account_type_label: string;
  signup_url: string;
  supports_oauth_sign_in?: boolean;
};
