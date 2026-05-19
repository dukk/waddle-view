import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('@/api/displayAuthMode', () => ({
  isDisplayProxyAuthEnabled: () => false,
}));

vi.mock('@/api/client', () => ({
  apiJson: vi.fn(),
}));

vi.mock('@/api/displayProxy', () => ({
  displayProxyFetch: vi.fn(),
}));

import { apiJson } from '@/api/client';
import { displayProxyFetch } from '@/api/displayProxy';
import { saveSession } from '@/storage/sessions';
import { remapOverlayBlobKeys } from './remapOverlayBlobKeys';

const source = { id: 'd-src', label: 'Source', baseUrl: 'https://src.test' };
const target = { id: 'd-tgt', label: 'Target', baseUrl: 'https://tgt.test' };

describe('remapOverlayBlobKeys', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
    saveSession('d-src', {
      apiKey: 'k-src',
      identifier: 'c',
      role: 'operator',
      permissions: ['overlays.write'],
      expiresAtMs: Date.now() + 60_000,
    });
    saveSession('d-tgt', {
      apiKey: 'k-tgt',
      identifier: 'c',
      role: 'operator',
      permissions: ['overlays.write'],
      expiresAtMs: Date.now() + 60_000,
    });
  });

  it('returns config unchanged when no blob keys', async () => {
    const cfg = { shapes: ['heart'] };
    await expect(remapOverlayBlobKeys(source, target, cfg)).resolves.toEqual(cfg);
    expect(displayProxyFetch).not.toHaveBeenCalled();
  });

  it('re-uploads blobs and rewrites keys', async () => {
    const bytes = new Uint8Array([1, 2, 3]);
    vi.mocked(displayProxyFetch).mockResolvedValue(
      new Response(bytes, {
        status: 200,
        headers: { 'content-type': 'image/png' },
      }),
    );
    vi.mocked(apiJson).mockResolvedValue({ blob_key: 'overlay/pool/new' });

    const out = await remapOverlayBlobKeys(source, target, {
      image_blob_keys: ['overlay/pool/old'],
    });

    expect(out).toEqual({ image_blob_keys: ['overlay/pool/new'] });
    expect(displayProxyFetch).toHaveBeenCalledWith(
      expect.stringContaining('overlay%2Fpool%2Fold'),
      expect.any(Object),
      expect.objectContaining({ display: source }),
    );
    expect(apiJson).toHaveBeenCalledWith(
      target,
      '/v1/display/overlays/blobs',
      expect.objectContaining({ method: 'POST' }),
    );
  });
});
