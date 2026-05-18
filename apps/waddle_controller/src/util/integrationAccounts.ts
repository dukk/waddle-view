export type IntegrationAccountType = {
  id: string;
  label: string;
  signup_url: string;
  integration_types: string[];
};

export type IntegrationAccountRequirement = {
  integration_type: string;
  account_type: string;
  account_type_label: string;
  signup_url: string;
};

export type IntegrationAccountRow = {
  id: string;
  account_type: string;
  account_type_label: string;
  label: string;
  signup_url?: string;
  configured: boolean;
  integration_types: string[];
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
};
