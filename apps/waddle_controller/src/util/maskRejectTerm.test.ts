import { describe, expect, it } from 'vitest';
import { maskRejectTermForDisplay } from './maskRejectTerm';

describe('maskRejectTermForDisplay', () => {
  it('returns empty for blank input', () => {
    expect(maskRejectTermForDisplay('')).toBe('');
    expect(maskRejectTermForDisplay('   ')).toBe('');
  });

  it('masks short terms', () => {
    expect(maskRejectTermForDisplay('a')).toBe('*');
    expect(maskRejectTermForDisplay('ab')).toBe('a*');
  });

  it('masks longer terms with middle asterisks', () => {
    expect(maskRejectTermForDisplay('hello')).toBe('h***o');
  });
});
