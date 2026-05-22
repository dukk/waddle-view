import { describe, expect, it } from 'vitest';
import {
  DISPLAY_SETTINGS_TAB_ACCOUNTS,
  DISPLAY_SETTINGS_TAB_ADVANCED,
  DISPLAY_SETTINGS_TAB_PROGRAMS,
  DISPLAY_SETTINGS_TAB_THEME,
  displaySettingsPath,
} from './displaySettingsTabs';

describe('displaySettingsTabs', () => {
  it('builds accounts tab path', () => {
    expect(displaySettingsPath(DISPLAY_SETTINGS_TAB_ACCOUNTS)).toBe(
      '/display-settings?tab=accounts',
    );
  });

  it('builds curator tab paths', () => {
    expect(displaySettingsPath(DISPLAY_SETTINGS_TAB_THEME)).toBe(
      '/display-settings?tab=theme',
    );
    expect(displaySettingsPath(DISPLAY_SETTINGS_TAB_PROGRAMS)).toBe(
      '/display-settings?tab=programs',
    );
    expect(displaySettingsPath(DISPLAY_SETTINGS_TAB_ADVANCED)).toBe(
      '/display-settings?tab=advanced',
    );
  });

  it('omits query for general tab', () => {
    expect(displaySettingsPath('general')).toBe('/display-settings');
    expect(displaySettingsPath()).toBe('/display-settings');
  });
});
