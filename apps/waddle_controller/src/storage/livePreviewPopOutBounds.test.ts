import { afterEach, describe, expect, it } from 'vitest';
import {
  LIVE_PREVIEW_POP_OUT_BOUNDS_KEY,
  LIVE_PREVIEW_POP_OUT_DEFAULT_HEIGHT,
  LIVE_PREVIEW_POP_OUT_DEFAULT_WIDTH,
  captureLivePreviewPopOutBounds,
  loadLivePreviewPopOutBounds,
  saveLivePreviewPopOutBounds,
} from '@/storage/livePreviewPopOutBounds';

describe('livePreviewPopOutBounds', () => {
  afterEach(() => {
    localStorage.removeItem(LIVE_PREVIEW_POP_OUT_BOUNDS_KEY);
  });

  it('round-trips bounds through localStorage', () => {
    saveLivePreviewPopOutBounds({ width: 900, height: 600, left: 120, top: 80 });
    expect(loadLivePreviewPopOutBounds()).toEqual({
      width: 900,
      height: 600,
      left: 120,
      top: 80,
    });
  });

  it('clamps out-of-range dimensions on save', () => {
    saveLivePreviewPopOutBounds({ width: 50, height: 600, left: 0, top: 0 });
    expect(loadLivePreviewPopOutBounds()).toEqual({
      width: 400,
      height: 600,
      left: 0,
      top: 0,
    });
  });

  it('captureLivePreviewPopOutBounds reads window metrics', () => {
    const fake = {
      outerWidth: 1024,
      outerHeight: 768,
      screenX: 40,
      screenY: 30,
    } as Window;
    expect(captureLivePreviewPopOutBounds(fake)).toEqual({
      width: 1024,
      height: 768,
      left: 40,
      top: 30,
    });
  });

  it('defaults are used when storage is empty', () => {
    expect(loadLivePreviewPopOutBounds()).toBeNull();
    expect(LIVE_PREVIEW_POP_OUT_DEFAULT_WIDTH).toBe(1100);
    expect(LIVE_PREVIEW_POP_OUT_DEFAULT_HEIGHT).toBe(780);
  });
});
