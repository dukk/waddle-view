import { describe, expect, it } from 'vitest';
import { pickPiTarballAsset } from './githubReleases.js';

describe('pickPiTarballAsset', () => {
  it('selects linux arm64 tarball', () => {
    const asset = pickPiTarballAsset([
      { name: 'waddle-view-windows-x64-v1.zip', browser_download_url: 'https://x/w.zip' },
      {
        name: 'waddle-view-linux-arm64-v1.0.0.tar.gz',
        browser_download_url: 'https://x/pi.tar.gz',
        size: 123,
      },
    ]);
    expect(asset?.name).toBe('waddle-view-linux-arm64-v1.0.0.tar.gz');
    expect(asset?.browser_download_url).toContain('pi.tar.gz');
  });
});
