import { describe, expect, it } from 'vitest';
import {
  ACTIVE_DISPLAY_STORAGE_KEY,
  readActiveDisplayPreference,
  resolveActiveDisplayId,
  writeActiveDisplayPreference,
} from './activeDisplayPreference';
import type { SavedDisplay } from './displays';

const displays: SavedDisplay[] = [
  { id: 'd_one', label: 'Kitchen', baseUrl: 'http://a' },
  { id: 'd_two', label: 'Living room', baseUrl: 'http://b' },
];

describe('activeDisplayPreference', () => {
  it('defaults to null when unset', () => {
    expect(readActiveDisplayPreference()).toBeNull();
  });

  it('round-trips a display id', () => {
    writeActiveDisplayPreference('d_two');
    expect(localStorage.getItem(ACTIVE_DISPLAY_STORAGE_KEY)).toBe('d_two');
    expect(readActiveDisplayPreference()).toBe('d_two');
    writeActiveDisplayPreference(null);
    expect(readActiveDisplayPreference()).toBeNull();
  });

  it('resolveActiveDisplayId prefers stored id when present in list', () => {
    writeActiveDisplayPreference('d_two');
    expect(resolveActiveDisplayId(displays)).toBe('d_two');
  });

  it('resolveActiveDisplayId falls back to first display when stored id is missing', () => {
    writeActiveDisplayPreference('d_gone');
    expect(resolveActiveDisplayId(displays)).toBe('d_one');
  });

  it('resolveActiveDisplayId returns null for an empty list', () => {
    writeActiveDisplayPreference('d_one');
    expect(resolveActiveDisplayId([])).toBeNull();
  });
});
