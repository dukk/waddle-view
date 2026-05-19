import { describe, expect, it } from 'vitest';
import { validateConfigAgainstSchema } from './rjsfSchema';
import { floatingBalloonsValidationSchema } from './floatingBalloonsConfigSchema';

describe('floatingBalloonsValidationSchema', () => {
  it('accepts valid balloon config', () => {
    const errors = validateConfigAgainstSchema(
      {
        colors: ['#E53935', '#00BCD4'],
        spawn_interval_sec: 22,
        rise_speed: 85,
        max_active: 6,
        cluster_chance: 0.4,
        balloon_scale: 0.09,
        scale_jitter: 0.25,
        opacity: 0.92,
      },
      floatingBalloonsValidationSchema,
    );
    expect(errors).toEqual([]);
  });

  it('accepts spawn_interval_sec at minimum of 1', () => {
    const errors = validateConfigAgainstSchema(
      { spawn_interval_sec: 1 },
      floatingBalloonsValidationSchema,
    );
    expect(errors).toEqual([]);
  });

  it('rejects spawn_interval_sec below minimum', () => {
    const errors = validateConfigAgainstSchema(
      { spawn_interval_sec: 0 },
      floatingBalloonsValidationSchema,
    );
    expect(errors.some((e) => e.includes('Spawn interval') && e.includes('>= 1'))).toBe(
      true,
    );
  });
});
