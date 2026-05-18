import { describe, expect, it } from 'vitest';
import {
  DISPLAY_SETTINGS_TAB_ACCOUNTS,
  displaySettingsPath,
} from './displaySettingsTabs';

describe('displaySettingsTabs', () => {
  it('builds accounts tab path', () => {
    expect(displaySettingsPath(DISPLAY_SETTINGS_TAB_ACCOUNTS)).toBe(
      '/display-settings?tab=accounts',
    );
  });

  it('omits query for general tab', () => {
    expect(displaySettingsPath('general')).toBe('/display-settings');
    expect(displaySettingsPath()).toBe('/display-settings');
  });
});
