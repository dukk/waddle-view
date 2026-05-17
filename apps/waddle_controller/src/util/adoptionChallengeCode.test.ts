import { describe, expect, it } from 'vitest';
import {
  formatAdoptionChallengeCodeInput,
  isAdoptionChallengeCodeComplete,
  normalizeAdoptionChallengeCode,
} from './adoptionChallengeCode';

describe('adoptionChallengeCode', () => {
  it('formats as XXXX-XXXX and uppercases', () => {
    expect(formatAdoptionChallengeCodeInput('ab12cd34')).toBe('AB12-CD34');
    expect(formatAdoptionChallengeCodeInput('ab12-cd34')).toBe('AB12-CD34');
  });

  it('normalizes by stripping separators', () => {
    expect(normalizeAdoptionChallengeCode('ab12-cd34')).toBe('AB12CD34');
  });

  it('detects complete codes', () => {
    expect(isAdoptionChallengeCodeComplete('AB12-CD34')).toBe(true);
    expect(isAdoptionChallengeCodeComplete('AB12')).toBe(false);
  });
});
