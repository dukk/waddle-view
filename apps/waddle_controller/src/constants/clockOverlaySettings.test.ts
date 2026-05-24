import { describe, expect, it } from 'vitest';
import {
  CLOCK_OVERLAY_POSITION_DEFAULT,
  CLOCK_OVERLAY_SCALE_DEFAULT,
  CLOCK_OVERLAY_SCALE_MAX,
  CLOCK_OVERLAY_SCALE_MIN,
  readClockOverlayPlacement,
} from './clockOverlaySettings';

describe('readClockOverlayPlacement', () => {
  it('uses defaults for empty input', () => {
    expect(readClockOverlayPlacement({})).toEqual({
      x: CLOCK_OVERLAY_POSITION_DEFAULT,
      y: CLOCK_OVERLAY_POSITION_DEFAULT,
      scale: CLOCK_OVERLAY_SCALE_DEFAULT,
    });
  });

  it('clamps x and y to 0..1', () => {
    expect(readClockOverlayPlacement({ x: -1, y: 2 })).toMatchObject({ x: 0, y: 1 });
    expect(readClockOverlayPlacement({ x: 0.5, y: 0.25 })).toMatchObject({ x: 0.5, y: 0.25 });
  });

  it('clamps scale to min..max', () => {
    expect(readClockOverlayPlacement({ scale: 0 })).toMatchObject({
      scale: CLOCK_OVERLAY_SCALE_MIN,
    });
    expect(readClockOverlayPlacement({ scale: 99 })).toMatchObject({
      scale: CLOCK_OVERLAY_SCALE_MAX,
    });
  });

  it('sets opacity only when below 1', () => {
    expect(readClockOverlayPlacement({ opacity: 1 })).not.toHaveProperty('opacity');
    expect(readClockOverlayPlacement({ opacity: 0.5 })).toMatchObject({ opacity: 0.5 });
  });

  it('uses fallbacks for non-finite values', () => {
    expect(readClockOverlayPlacement({ x: NaN, y: 'bad', scale: Infinity })).toEqual({
      x: CLOCK_OVERLAY_POSITION_DEFAULT,
      y: CLOCK_OVERLAY_POSITION_DEFAULT,
      scale: CLOCK_OVERLAY_SCALE_DEFAULT,
    });
  });
});
