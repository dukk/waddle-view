import { describe, expect, it } from 'vitest';
import { formatProgramDuration, formatProgramDurationWithSeconds } from './programDurationFormat';

describe('formatProgramDuration', () => {
  it('formats seconds only', () => {
    expect(formatProgramDuration(45)).toBe('45 sec');
  });

  it('formats minutes only', () => {
    expect(formatProgramDuration(120)).toBe('2 min');
  });

  it('formats minutes and seconds', () => {
    expect(formatProgramDuration(195)).toBe('3 min 15 sec');
  });

  it('includes total seconds in extended form', () => {
    expect(formatProgramDurationWithSeconds(180)).toBe('3 min (180s)');
  });
});
