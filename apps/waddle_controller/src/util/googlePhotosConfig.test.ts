import { describe, expect, it } from 'vitest';
import {
  buildGooglePhotosConfigJson,
  mergePickedMediaIds,
  parseGooglePhotosConfig,
} from '@/util/googlePhotosConfig';

describe('googlePhotosConfig', () => {
  it('parse and build round-trip', () => {
    const raw = {
      globalPerPollLimit: 25,
      accounts: [
        {
          googleAccountKey: 'family',
          sources: [
            {
              sourceId: 'a1',
              albumLabel: 'Vacation',
              albumSearchHint: 'Vacation 2025',
              category: 'family_media',
              maxFiles: 100,
              perPollLimit: 5,
              mediaItemIds: ['m1', 'm2'],
              pickerSessionId: 'sess-1',
              lastPickedAtMs: 1000,
            },
          ],
        },
      ],
    };
    const state = parseGooglePhotosConfig(raw);
    expect(state.googleAccountKey).toBe('family');
    expect(state.globalPerPollLimit).toBe(25);
    expect(state.sources).toHaveLength(1);
    expect(state.sources[0]?.mediaItemIds).toEqual(['m1', 'm2']);

    const built = buildGooglePhotosConfigJson(state);
    expect(built.globalPerPollLimit).toBe(25);
    const accounts = built.accounts as Record<string, unknown>[];
    expect(accounts).toHaveLength(1);
  });

  it('mergePickedMediaIds dedupes', () => {
    expect(mergePickedMediaIds(['a', 'b'], ['b', 'c'])).toEqual(['a', 'b', 'c']);
  });
});
