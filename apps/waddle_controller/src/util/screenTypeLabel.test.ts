import { describe, expect, it } from 'vitest';
import { screenTypeLabel } from './screenTypeLabel';

describe('screenTypeLabel', () => {
  it('prefers registry label when present', () => {
    expect(
      screenTypeLabel('weather', {
        screen_type: 'weather',
        label: 'Weather',
        config_json_schema: { title: 'Weather Widget' },
      }),
    ).toBe('Weather');
  });

  it('uses schema title when present', () => {
    expect(
      screenTypeLabel('weather', {
        screen_type: 'weather',
        config_json_schema: { title: 'Weather Widget' },
      }),
    ).toBe('Weather Widget');
  });

  it('falls back to underscore-separated words', () => {
    expect(screenTypeLabel('stock_quotes')).toBe('stock quotes');
  });

  it('returns unknown for empty type', () => {
    expect(screenTypeLabel('')).toBe('unknown');
  });
});
