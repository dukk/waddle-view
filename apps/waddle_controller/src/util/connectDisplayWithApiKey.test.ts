import { beforeEach, describe, expect, it, vi } from 'vitest';
import { connectDisplayWithApiKey } from '@/util/connectDisplayWithApiKey';

vi.mock('@/api/adoption', () => ({
  fetchAdoptionSession: vi.fn(),
}));

vi.mock('@/storage/displays', () => ({
  normalizeBaseUrl: (u: string) => u.replace(/\/+$/, ''),
  addDisplay: vi.fn(() => ({
    id: 'display-1',
    baseUrl: 'https://kiosk.test',
    label: 'Lab',
  })),
}));

vi.mock('@/storage/sessions', () => ({
  saveSession: vi.fn(),
}));

vi.mock('@/storage/userDisplaysSync', () => ({
  syncUserDisplayToServer: vi.fn().mockResolvedValue(undefined),
}));

import { fetchAdoptionSession } from '@/api/adoption';
import { saveSession } from '@/storage/sessions';

describe('connectDisplayWithApiKey', () => {
  beforeEach(() => {
    vi.mocked(fetchAdoptionSession).mockReset();
  });

  it('validates key then persists display and session', async () => {
    vi.mocked(fetchAdoptionSession).mockResolvedValue({
      identifier: 'manual-client',
      role: 'operator',
      permissions: ['telemetry.read'],
    });

    const { display, session } = await connectDisplayWithApiKey({
      baseUrl: 'https://kiosk.test/',
      apiKey: 'wd_manual_key',
      label: 'Lab',
    });

    expect(fetchAdoptionSession).toHaveBeenCalledWith('https://kiosk.test', 'wd_manual_key');
    expect(display.id).toBe('display-1');
    expect(session.apiKey).toBe('wd_manual_key');
    expect(session.identifier).toBe('manual-client');
    expect(saveSession).toHaveBeenCalledWith('display-1', session);
  });

  it('rejects empty api key', async () => {
    await expect(
      connectDisplayWithApiKey({
        baseUrl: 'https://kiosk.test',
        apiKey: '   ',
      }),
    ).rejects.toThrow('API key is required');
  });
});
