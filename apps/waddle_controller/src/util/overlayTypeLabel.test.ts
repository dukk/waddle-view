import { describe, expect, it } from 'vitest';
import { overlayTypeLabel } from './overlayTypeLabel';

describe('overlayTypeLabel', () => {
  it('prefers registry label when present', () => {
    expect(
      overlayTypeLabel('shape_rain', {
        overlay_type: 'shape_rain',
        label: 'Shape rain',
      }),
    ).toBe('Shape rain');
  });

  it('falls back to built-in map', () => {
    expect(overlayTypeLabel('birthday_confetti')).toBe('Birthday confetti');
  });
});
