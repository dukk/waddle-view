import { afterEach, describe, expect, it } from 'vitest';
import {
  LIVE_PREVIEW_POP_OUT_BOUNDS_KEY,
  saveLivePreviewPopOutBounds,
} from '@/storage/livePreviewPopOutBounds';
import {
  LIVE_PREVIEW_POP_OUT_FEATURES,
  LIVE_PREVIEW_POP_OUT_PATH,
  buildLivePreviewPopOutFeatures,
  buildLivePreviewPopOutUrl,
} from '@/util/openLivePreviewPopOut';

describe('openLivePreviewPopOut', () => {
  afterEach(() => {
    localStorage.removeItem(LIVE_PREVIEW_POP_OUT_BOUNDS_KEY);
  });

  it('buildLivePreviewPopOutUrl encodes display and ticket', () => {
    const url = buildLivePreviewPopOutUrl({
      displayId: 'living-room',
      ticket: 'abc+123',
    });
    expect(url).toBe(
      `${LIVE_PREVIEW_POP_OUT_PATH}?displayId=living-room&ticket=abc%2B123`,
    );
  });

  it('LIVE_PREVIEW_POP_OUT_FEATURES requests popup chrome', () => {
    expect(LIVE_PREVIEW_POP_OUT_FEATURES).toContain('popup=yes');
    expect(LIVE_PREVIEW_POP_OUT_FEATURES).toContain('toolbar=no');
    expect(LIVE_PREVIEW_POP_OUT_FEATURES).toContain('location=no');
  });

  it('buildLivePreviewPopOutFeatures applies stored bounds', () => {
    saveLivePreviewPopOutBounds({ width: 920, height: 640, left: 100, top: 50 });
    const features = buildLivePreviewPopOutFeatures();
    expect(features).toContain('width=920');
    expect(features).toContain('height=640');
    expect(features).toContain('left=100');
    expect(features).toContain('top=50');
  });

  it('buildLivePreviewPopOutFeatures uses explicit bounds over storage', () => {
    saveLivePreviewPopOutBounds({ width: 920, height: 640, left: 100, top: 50 });
    const features = buildLivePreviewPopOutFeatures({
      width: 800,
      height: 500,
      left: 10,
      top: 20,
    });
    expect(features).toContain('width=800');
    expect(features).toContain('left=10');
    expect(features).not.toContain('width=920');
  });
});
