import { beforeEach, describe, expect, it, vi } from 'vitest';
import { fetchControllerAbout } from './bffAbout';

vi.mock('./bffClient', () => ({
  bffJson: vi.fn(),
}));

import { bffJson } from './bffClient';

describe('fetchControllerAbout', () => {
  beforeEach(() => {
    vi.mocked(bffJson).mockReset();
  });

  it('calls bffJson with /about', async () => {
    const payload = {
      app: 'waddle_controller',
      version: '1.0.0',
      build: '1',
      productLicense: { id: 'ONC', name: 'ONC', url: 'https://example.com', summary: '' },
      dependencies: [],
      thirdPartyNotices: '',
    };
    vi.mocked(bffJson).mockResolvedValue(payload);
    const result = await fetchControllerAbout();
    expect(result).toEqual(payload);
    expect(bffJson).toHaveBeenCalledWith('/about');
  });
});
