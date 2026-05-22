import { describe, expect, it } from 'vitest';
import { liveScreenLabelFromProgram } from '@/util/liveScreenLabel';

describe('liveScreenLabelFromProgram', () => {
  it('returns null when program has no slides', () => {
    expect(liveScreenLabelFromProgram({ slides: [] })).toBeNull();
  });

  it('labels a single slide with catalog name when available', () => {
    const row = {
      slides: [
        {
          screen_id: 'welcome',
          screen_type: 'weather',
          dwell_ms: 5000,
          layout_json: '{}',
        },
      ],
    };
    const map = new Map([['welcome', 'Welcome board']]);
    const info = liveScreenLabelFromProgram(row, { screenLabelById: map });
    expect(info?.summary).toBe('Welcome board');
    expect(info?.screenIds).toEqual(['welcome']);
  });

  it('summarizes rotation when multiple slides', () => {
    const row = {
      slides: [
        { screen_id: 'a', screen_type: 'news', dwell_ms: 1000, layout_json: '{}' },
        { screen_id: 'b', screen_type: 'weather', dwell_ms: 2000, layout_json: '{}' },
      ],
    };
    const info = liveScreenLabelFromProgram(row, {
      screenTypeDisplayLabel: (st) => st,
    });
    expect(info?.summary).toBe('Rotation: a (news), b (weather)');
  });
});
