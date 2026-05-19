import { describe, expect, it } from 'vitest';
import {
  DEFAULT_DISPLAY_IMAGE_OVERLAY,
  normalizeDisplayImageOverlay,
} from '@/constants/displayImageOverlaySettings';

describe('normalizeDisplayImageOverlay', () => {
  it('returns defaults for invalid input', () => {
    expect(normalizeDisplayImageOverlay(null)).toEqual(DEFAULT_DISPLAY_IMAGE_OVERLAY);
  });

  it('clamps position and scale', () => {
    const out = normalizeDisplayImageOverlay({
      enabled: true,
      image_blob_key: 'overlay/pool/logo',
      x: 2,
      y: -1,
      scale: 99,
      opacity: 1.5,
    });
    expect(out.x).toBe(1);
    expect(out.y).toBe(0);
    expect(out.scale).toBe(0.7);
    expect(out.opacity).toBeUndefined();
  });

  it('omits opacity when fully opaque', () => {
    const out = normalizeDisplayImageOverlay({ opacity: 1 });
    expect(out.opacity).toBeUndefined();
  });
});
