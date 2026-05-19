import { describe, expect, it } from 'vitest';
import {
  DEFAULT_STATIC_IMAGE_OVERLAY_CONFIG,
  normalizeStaticImageOverlayConfig,
} from '@/constants/staticImageOverlaySettings';

describe('normalizeStaticImageOverlayConfig', () => {
  it('returns defaults when raw is null', () => {
    expect(normalizeStaticImageOverlayConfig(null)).toEqual(
      DEFAULT_STATIC_IMAGE_OVERLAY_CONFIG,
    );
  });

  it('clamps position and scale', () => {
    const out = normalizeStaticImageOverlayConfig({
      image_blob_key: 'overlay/pool/logo',
      x: 2,
      y: -1,
      scale: 99,
      opacity: 1.5,
    });
    expect(out.image_blob_key).toBe('overlay/pool/logo');
    expect(out.x).toBe(1);
    expect(out.y).toBe(0);
    expect(out.scale).toBe(0.7);
    expect(out.opacity).toBeUndefined();
  });

  it('omits full opacity', () => {
    const out = normalizeStaticImageOverlayConfig({ opacity: 1 });
    expect(out.opacity).toBeUndefined();
  });
});
