import { describe, expect, it, vi } from 'vitest';
import {
  resolveOverlayBlobUploadMime,
  uploadOverlayImageBlob,
} from './overlayBlobs';

vi.mock('@/api/client', () => ({
  apiJson: vi.fn(),
}));

import { apiJson } from '@/api/client';

describe('resolveOverlayBlobUploadMime', () => {
  it('infers SVG from extension when type is empty', () => {
    const file = new File(['<svg></svg>'], 'icon.svg', { type: '' });
    expect(resolveOverlayBlobUploadMime(file)).toBe('image/svg+xml');
  });
});

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
        headers: { 'Content-Type': 'application/json' },
        body: expect.any(String),
      }),
    );
    const init = vi.mocked(apiJson).mock.calls[0]![2] as RequestInit;
    const body = JSON.parse(String(init.body)) as {
      content_type: string;
      bytes_base64: string;
    };
    expect(body.content_type).toBe('image/png');
    expect(body.bytes_base64).toEqual(expect.any(String));
  });

  it('accepts SVG uploads', async () => {
    vi.mocked(apiJson).mockResolvedValue({ blob_key: 'overlay/pool/svg' });
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>';
    const bytes = new TextEncoder().encode(svg);
    const file = new File([bytes], 'icon.svg', { type: 'image/svg+xml' });
    Object.defineProperty(file, 'arrayBuffer', {
      value: async () => bytes.buffer,
    });
    const display = { id: 'd1', baseUrl: 'http://x' } as never;
    await uploadOverlayImageBlob(display, file);
    const init = vi.mocked(apiJson).mock.calls.at(-1)![2] as RequestInit;
    const body = JSON.parse(String(init.body)) as { content_type: string };
    expect(body.content_type).toBe('image/svg+xml');
  });

  it('rejects unsupported mime types', async () => {
    const file = new File(['%PDF'], 'doc.pdf', { type: 'application/pdf' });
    await expect(
      uploadOverlayImageBlob({ id: 'd1', baseUrl: 'http://x' } as never, file),
    ).rejects.toThrow(/SVG/);
  });
});
