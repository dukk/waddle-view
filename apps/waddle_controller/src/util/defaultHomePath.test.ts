import { afterEach, describe, expect, it } from 'vitest';
import type { SavedDisplay } from '@/storage/displays';
import { saveSession } from '@/storage/sessions';
import { defaultHomePath } from '@/util/defaultHomePath';

const display: SavedDisplay = {
  id: 'd1',
  baseUrl: 'https://127.0.0.1:8787',
  label: 'Kiosk',
};

describe('defaultHomePath', () => {
  afterEach(() => {
    localStorage.clear();
    sessionStorage.clear();
  });

  it('returns /controller-settings when there are no saved displays', () => {
    expect(defaultHomePath([], false)).toBe('/controller-settings');
  });

  it('returns /controller-settings when displays exist but none are adopted', () => {
    expect(defaultHomePath([display], false)).toBe('/controller-settings');
  });

  it('returns /display-settings when at least one display is adopted', () => {
    saveSession(display.id, {
      apiKey: 'key',
      identifier: 'op',
      role: 'admin',
      permissions: [],
      expiresAtMs: Date.now() + 60_000,
    });
    expect(defaultHomePath([display], false)).toBe('/display-settings');
  });

  it('returns /programs for programs-only users with adoption', () => {
    saveSession(display.id, {
      apiKey: 'key',
      identifier: 'viewer',
      role: 'viewer',
      permissions: [],
      expiresAtMs: Date.now() + 60_000,
    });
    expect(defaultHomePath([display], true)).toBe('/programs');
  });
});
