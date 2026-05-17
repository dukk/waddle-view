import { beforeEach, describe, expect, it } from 'vitest';
import {
  displaysForBaseUrl,
  suggestAdoptionIdentifier,
  suggestDisplayLabel,
} from '@/util/adoptionDisplayIdentity';
import { applyDisplayAdoption, clearDisplaysStorage, saveDisplays } from '@/storage/displays';

describe('adoptionDisplayIdentity', () => {
  beforeEach(() => {
    clearDisplaysStorage();
  });

  it('suggestAdoptionIdentifier keeps stem for first display adoption', () => {
    expect(suggestAdoptionIdentifier('https://display.test', 'admin', 'wc-host')).toBe('wc-host');
  });

  it('suggestAdoptionIdentifier suffixes role for second role on same URL', () => {
    saveDisplays([
      {
        id: 'd1',
        label: 'Display',
        baseUrl: 'https://display.test',
        identifier: 'wc-host',
        role: 'admin',
      },
    ]);
    expect(suggestAdoptionIdentifier('https://display.test', 'operator', 'wc-host')).toBe(
      'wc-host-operator',
    );
  });

  it('suggestAdoptionIdentifier adds numeric suffix when role id is taken', () => {
    saveDisplays([
      {
        id: 'd1',
        label: 'A',
        baseUrl: 'https://display.test',
        identifier: 'wc-host-operator',
        role: 'operator',
      },
    ]);
    expect(suggestAdoptionIdentifier('https://display.test', 'operator', 'wc-host')).toBe(
      'wc-host-operator-2',
    );
  });

  it('suggestDisplayLabel includes role when display already saved', () => {
    saveDisplays([{ id: 'd1', label: '127.0.0.1', baseUrl: 'https://127.0.0.1:8787' }]);
    expect(suggestDisplayLabel('https://127.0.0.1:8787', 'viewer')).toBe('127.0.0.1:8787 (viewer)');
  });

  it('displaysForBaseUrl matches normalized URLs', () => {
    saveDisplays([{ id: 'd1', label: 'K', baseUrl: 'https://display.test/' }]);
    applyDisplayAdoption('d1', {
      apiKey: 'wd_a',
      role: 'admin',
      identifier: 'wc-host',
    });
    expect(displaysForBaseUrl('https://display.test')).toHaveLength(1);
    expect(displaysForBaseUrl('https://display.test')[0]?.role).toBe('admin');
  });
});
