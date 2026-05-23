import { describe, expect, it } from 'vitest';
import {
  defaultDurationUnit,
  durationPartsToSeconds,
  formatDurationSummary,
  formatIntervalDisplay,
  resolveDurationUnit,
  secondsToDurationParts,
} from './durationInput';

describe('durationInput', () => {
  it('converts between units and seconds', () => {
    expect(durationPartsToSeconds(2, 'min')).toBe(120);
    expect(secondsToDurationParts(120, 'min')).toEqual({ amount: 2, unit: 'min' });
  });

  it('defaultDurationUnit picks hr for even hours', () => {
    expect(defaultDurationUnit(7200, ['sec', 'min', 'hr'])).toBe('hr');
  });

  it('formatDurationSummary combines parts', () => {
    expect(formatDurationSummary(195)).toBe('3 min 15 sec');
  });

  it('formatIntervalDisplay uses full words via poll formatter', () => {
    expect(formatIntervalDisplay(125)).toBe('2 minutes 5 seconds');
  });

  it('resolveDurationUnit prefers default when allowed', () => {
    expect(resolveDurationUnit(3600, ['sec', 'min', 'hr'], 'min')).toBe('min');
    expect(resolveDurationUnit(3600, ['sec', 'min', 'hr'], 'hr')).toBe('hr');
    expect(resolveDurationUnit(45, ['sec', 'min'], 'min')).toBe('min');
  });
});
