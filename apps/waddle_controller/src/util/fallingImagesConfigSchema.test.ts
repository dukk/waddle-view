import { describe, expect, it } from 'vitest';
import { validateConfigAgainstSchema } from './rjsfSchema';
import { fallingImagesValidationSchema } from './fallingImagesConfigSchema';

describe('fallingImagesValidationSchema', () => {
  it('accepts drop_interval_sec at the new minimum (5)', () => {
    const errors = validateConfigAgainstSchema(
      {
        image_blob_keys: ['overlay/pool/1'],
        drop_interval_sec: 5,
        fall_speed: 130,
        image_scale: 0.12,
        scale_jitter: 0.33,
      },
      fallingImagesValidationSchema,
    );
    expect(errors).toEqual([]);
  });

  it('rejects drop_interval_sec below minimum', () => {
    const errors = validateConfigAgainstSchema(
      { drop_interval_sec: 4 },
      fallingImagesValidationSchema,
    );
    expect(errors.some((e) => e.includes('Drop interval') && e.includes('>= 5'))).toBe(
      true,
    );
  });
});
