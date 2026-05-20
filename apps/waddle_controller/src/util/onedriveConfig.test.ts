import { describe, expect, it } from 'vitest';
import {
  buildOneDriveConfigJson,
  isWindowsLocalOneDrivePath,
  onedriveConfigReady,
  parseOneDriveConfig,
} from '@/util/onedriveConfig';

describe('onedriveConfig', () => {
  it('parse and build round-trip with categoryIds', () => {
    const raw = {
      globalPerPollLimit: 30,
      accounts: [
        {
          graphAccountKey: 'home',
          sources: [
            {
              sourceId: 's1',
              folderLabel: 'Pictures',
              path: '/Pictures',
              kind: 'photo',
              categoryIds: ['family', 'travel'],
              maxFiles: 80,
            },
          ],
        },
      ],
    };
    const state = parseOneDriveConfig(raw, 'photo');
    expect(state.globalPerPollLimit).toBe(30);
    expect(state.accounts).toHaveLength(1);
    expect(state.accounts[0]?.sources[0]?.categoryIds).toEqual(['family', 'travel']);

    const built = buildOneDriveConfigJson(state, 'photo');
    expect(built.globalPerPollLimit).toBe(30);
    const accounts = built.accounts as Record<string, unknown>[];
    const sources = (accounts[0]?.sources as Record<string, unknown>[]) ?? [];
    expect(sources[0]?.kind).toBe('photo');
    expect(sources[0]?.categoryIds).toEqual(['family', 'travel']);
  });

  it('parses legacy category string as single categoryIds entry', () => {
    const state = parseOneDriveConfig(
      {
        accounts: [
          {
            graphAccountKey: 'home',
            sources: [{ path: '', category: 'onedrive', maxFiles: 50 }],
          },
        ],
      },
      'video',
    );
    expect(state.accounts[0]?.sources[0]?.categoryIds).toEqual(['onedrive']);
    expect(state.accounts[0]?.sources[0]?.path).toBe('');
  });

  it('onedriveConfigReady accepts drive root path', () => {
    expect(
      onedriveConfigReady({
        globalPerPollLimit: 50,
        accounts: [
          {
            graphAccountKey: 'home',
            sources: [{ sourceId: 'r', folderLabel: 'Root', path: '', categoryIds: ['pics'], maxFiles: 50 }],
          },
        ],
      }),
    ).toBe(true);
  });

  it('isWindowsLocalOneDrivePath detects drive letters and OneDrive user folders', () => {
    expect(isWindowsLocalOneDrivePath('C:\\Users\\dukk\\OneDrive\\Pictures')).toBe(true);
    expect(isWindowsLocalOneDrivePath('/Pictures/Family')).toBe(false);
  });

  it('onedriveConfigReady rejects Windows local paths', () => {
    expect(
      onedriveConfigReady({
        globalPerPollLimit: 50,
        accounts: [
          {
            graphAccountKey: 'home',
            sources: [
              {
                sourceId: 's',
                folderLabel: 'Bad',
                path: 'C:\\Users\\x\\OneDrive\\Pictures',
                categoryIds: ['general'],
                maxFiles: 50,
              },
            ],
          },
        ],
      }),
    ).toBe(false);
  });

  it('onedriveConfigReady requires account and categoryIds', () => {
    expect(onedriveConfigReady({ globalPerPollLimit: 50, accounts: [] })).toBe(false);
    expect(
      onedriveConfigReady({
        globalPerPollLimit: 50,
        accounts: [{ graphAccountKey: '', sources: [] }],
      }),
    ).toBe(false);
  });
});
