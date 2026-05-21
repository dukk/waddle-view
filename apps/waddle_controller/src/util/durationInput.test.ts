import { describe, expect, it } from 'vitest';
import {
  defaultDurationUnit,
  durationPartsToSeconds,
  formatDurationSummary,
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
});
