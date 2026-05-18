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

export type IntegrationAccountRow = {
  id: string;
  account_type: string;
  account_type_label: string;
  label: string;
  signup_url?: string;
  supports_oauth_sign_in?: boolean;
  configured: boolean;
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
