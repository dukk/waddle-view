import { describe, expect, it, vi } from 'vitest';
import {
  buildLivePreviewFrameFilename,
  downloadLivePreviewFrameToBrowser,
  livePreviewFrameExtension,
  parseLivePreviewFrame,
} from '@/util/livePreviewFrame';

function encodeLegacyJpegFrame(jpegPayload: Uint8Array): ArrayBuffer {
  const buf = new ArrayBuffer(4 + jpegPayload.length);
  const view = new DataView(buf);
  view.setUint32(0, jpegPayload.length, false);
  new Uint8Array(buf).set(jpegPayload, 4);
  return buf;
}

function encodeFramedFrame(
  payload: Uint8Array,
  format: 0 | 1,
): ArrayBuffer {
  const buf = new ArrayBuffer(5 + payload.length);
  const view = new DataView(buf);
  view.setUint32(0, payload.length, false);
  view.setUint8(4, format);
  new Uint8Array(buf).set(payload, 5);
  return buf;
}

describe('parseLivePreviewFrame', () => {
  it('parses legacy JPEG frame with 4-byte length header', () => {
    const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
    const parsed = parseLivePreviewFrame(encodeLegacyJpegFrame(jpeg));
    expect(parsed).toEqual({
      mime: 'image/jpeg',
      payload: jpeg.buffer.slice(jpeg.byteOffset, jpeg.byteOffset + jpeg.length),
    });
  });

  it('parses v5 JPEG frame with format byte 0', () => {
    const jpeg = new Uint8Array([0x00, 0x01, 0x02]);
    const parsed = parseLivePreviewFrame(encodeFramedFrame(jpeg, 0));
    expect(parsed?.mime).toBe('image/jpeg');
    expect(new Uint8Array(parsed!.payload)).toEqual(jpeg);
  });

  it('parses v5 PNG frame with format byte 1', () => {
    const png = new Uint8Array([0x89, 0x50, 0x4e, 0x47]);
    const parsed = parseLivePreviewFrame(encodeFramedFrame(png, 1));
    expect(parsed?.mime).toBe('image/png');
    expect(new Uint8Array(parsed!.payload)).toEqual(png);
  });

  it('returns null for truncated buffer', () => {
    const buf = new ArrayBuffer(6);
    const view = new DataView(buf);
    view.setUint32(0, 100, false);
    view.setUint8(4, 0);
    expect(parseLivePreviewFrame(buf)).toBeNull();
  });

  it('returns null for zero length', () => {
    const buf = new ArrayBuffer(5);
    new DataView(buf).setUint32(0, 0, false);
    expect(parseLivePreviewFrame(buf)).toBeNull();
  });
});

describe('buildLivePreviewFrameFilename', () => {
  it('uses jpg extension for jpeg mime', () => {
    const at = new Date('2026-05-23T14:30:52.000Z');
    expect(buildLivePreviewFrameFilename('living-room', 'image/jpeg', at)).toBe(
      'waddle_live_preview_living-room_2026-05-23T14-30-52.jpg',
    );
  });

  it('uses png extension for png mime', () => {
    const at = new Date('2026-05-23T14:30:52.000Z');
    expect(buildLivePreviewFrameFilename('d1', 'image/png', at)).toBe(
      'waddle_live_preview_d1_2026-05-23T14-30-52.png',
    );
  });
});

describe('livePreviewFrameExtension', () => {
  it('maps mime types', () => {
    expect(livePreviewFrameExtension('image/jpeg')).toBe('jpg');
    expect(livePreviewFrameExtension('image/png')).toBe('png');
  });
});

describe('downloadLivePreviewFrameToBrowser', () => {
  it('creates blob URL and triggers anchor download', () => {
    const createUrl = vi.fn(() => 'blob:test');
    const revoke = vi.fn();
    vi.stubGlobal('URL', { createObjectURL: createUrl, revokeObjectURL: revoke });

    const click = vi.fn();
    const anchor = { href: '', download: '', click } as HTMLAnchorElement;
    vi.spyOn(document, 'createElement').mockReturnValue(anchor);

    const payload = new Uint8Array([0xff, 0xd8]).buffer;
    downloadLivePreviewFrameToBrowser(
      { mime: 'image/jpeg', payload },
      'display-1',
      new Date('2026-05-23T14:30:52.000Z'),
    );

    expect(createUrl).toHaveBeenCalled();
    expect(anchor.download).toBe('waddle_live_preview_display-1_2026-05-23T14-30-52.jpg');
    expect(click).toHaveBeenCalled();
    expect(revoke).toHaveBeenCalledWith('blob:test');
  });
});
