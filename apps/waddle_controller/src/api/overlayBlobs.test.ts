import { describe, expect, it, vi } from 'vitest';
import { uploadOverlayImageBlob } from './overlayBlobs';

vi.mock('@/api/client', () => ({
  apiJson: vi.fn(),
}));

import { apiJson } from '@/api/client';

describe('uploadOverlayImageBlob', () => {
  it('rejects oversized files', async () => {
    const big = new File([new Uint8Array(5 * 1024 * 1024)], 'big.png', {
      type: 'image/png',
    });
    await expect(
      uploadOverlayImageBlob({ id: 'd1', baseUrl: 'http://x' } as never, big),
    ).rejects.toThrow(/4 MB/);
  });

  it('posts base64 payload', async () => {
    vi.mocked(apiJson).mockResolvedValue({ blob_key: 'overlay/pool/1' });
    const bytes = new Uint8Array([1, 2, 3]);
    const file = new File([bytes], 'a.png', { type: 'image/png' });
    Object.defineProperty(file, 'arrayBuffer', {
      value: async () => bytes.buffer,
    });
    const display = { id: 'd1', baseUrl: 'http://x' } as never;
    const res = await uploadOverlayImageBlob(display, file);
    expect(res.blob_key).toBe('overlay/pool/1');
    expect(apiJson).toHaveBeenCalledWith(
      display,
      '/v1/display/overlays/blobs',
      expect.objectContaining({
        method: 'POST',
        body: expect.objectContaining({
          content_type: 'image/png',
          bytes_base64: expect.any(String),
        }),
      }),
    );
  });
});
