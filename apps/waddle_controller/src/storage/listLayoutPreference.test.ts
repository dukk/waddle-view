import { describe, expect, it } from 'vitest';
import {
  LIST_LAYOUT_STORAGE_KEY,
  readListLayoutPreference,
  writeListLayoutPreference,
} from './listLayoutPreference';

describe('listLayoutPreference', () => {
  it('defaults each page to card', () => {
    expect(readListLayoutPreference('screens')).toBe('card');
    expect(readListLayoutPreference('displays')).toBe('card');
  });

  it('round-trips table and card per page', () => {
    writeListLayoutPreference('screens', 'table');
    writeListLayoutPreference('integrations', 'card');
    expect(localStorage.getItem(LIST_LAYOUT_STORAGE_KEY)).toContain('"screens":"table"');
    expect(readListLayoutPreference('screens')).toBe('table');
    expect(readListLayoutPreference('integrations')).toBe('card');
    writeListLayoutPreference('screens', 'card');
    expect(readListLayoutPreference('screens')).toBe('card');
  });

  it('ignores invalid stored values', () => {
    localStorage.setItem(LIST_LAYOUT_STORAGE_KEY, '{"screens":"grid"}');
    expect(readListLayoutPreference('screens')).toBe('card');
  });
});
