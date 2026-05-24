import { beforeEach, describe, expect, it, vi } from 'vitest';
import { fetchLatestWaddleViewRelease } from './githubReleases';

vi.mock('./bffClient', () => ({
  bffJson: vi.fn(),
}));

import { bffJson } from './bffClient';

describe('fetchLatestWaddleViewRelease', () => {
  beforeEach(() => {
    vi.mocked(bffJson).mockReset();
  });

  it('calls bffJson with releases path', async () => {
    const release = {
      tag_name: 'v1.0.0',
      name: 'v1.0.0',
      published_at: '2026-01-01T00:00:00Z',
      html_url: 'https://github.com/dukk/waddle-view/releases/tag/v1.0.0',
      body: 'Notes',
      pi_asset: null,
    };
    vi.mocked(bffJson).mockResolvedValue(release);
    const result = await fetchLatestWaddleViewRelease();
    expect(result).toEqual(release);
    expect(bffJson).toHaveBeenCalledWith('/releases/waddle-view');
  });
});
