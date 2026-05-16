import { describe, expect, it } from 'vitest';
import {
  COLOR_MODE_STORAGE_KEY,
  readColorModePreference,
  writeColorModePreference,
} from './colorModePreference';

describe('colorModePreference', () => {
  it('defaults to system', () => {
    expect(readColorModePreference()).toBe('system');
  });

  it('round-trips light and dark', () => {
    writeColorModePreference('dark');
    expect(localStorage.getItem(COLOR_MODE_STORAGE_KEY)).toBe('dark');
    expect(readColorModePreference()).toBe('dark');
    writeColorModePreference('light');
    expect(readColorModePreference()).toBe('light');
  });

  it('ignores invalid stored values', () => {
    localStorage.setItem(COLOR_MODE_STORAGE_KEY, 'sepia');
    expect(readColorModePreference()).toBe('system');
  });
});
