/** Operator-facing label for the accounts tab (links and inline help). */
export const DISPLAY_SETTINGS_ACCOUNTS_LABEL = 'Display settings → Accounts';

export const DISPLAY_SETTINGS_TAB_ACCOUNTS = 'accounts';
export const DISPLAY_SETTINGS_TAB_GENERAL = 'general';
export const DISPLAY_SETTINGS_TAB_ADOPTION = 'adoption';

export type DisplaySettingsTabId =
  | typeof DISPLAY_SETTINGS_TAB_GENERAL
  | typeof DISPLAY_SETTINGS_TAB_ACCOUNTS
  | typeof DISPLAY_SETTINGS_TAB_ADOPTION;

export function displaySettingsPath(tab?: string): string {
  if (!tab || tab === DISPLAY_SETTINGS_TAB_GENERAL) {
    return '/display-settings';
  }
  return `/display-settings?tab=${encodeURIComponent(tab)}`;
}
