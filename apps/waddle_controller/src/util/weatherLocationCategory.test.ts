import { describe, expect, it } from 'vitest';
import {
  interestCategoryLabel,
  weatherLocationCategoryFromName,
} from './weatherLocationCategory';

describe('weatherLocationCategoryFromName', () => {
  it('maps US state suffix to north_america', () => {
    expect(weatherLocationCategoryFromName('Boston, MA')).toBe('north_america');
  });

  it('maps country suffix to continental region', () => {
    expect(weatherLocationCategoryFromName('Paris, France')).toBe('europe');
    expect(weatherLocationCategoryFromName('Sydney, Australia')).toBe('oceania');
  });
});

describe('interestCategoryLabel', () => {
  const curator = [{ id: 'united_states', label: 'United States' }];

  it('uses curator label when present', () => {
    expect(interestCategoryLabel('united_states', curator)).toBe('United States');
  });

  it('title-cases unknown slug ids', () => {
    expect(interestCategoryLabel('united_kingdom', curator)).toBe('United Kingdom');
  });

  it('treats missing category as general', () => {
    expect(interestCategoryLabel(undefined, curator)).toBe('General');
    expect(interestCategoryLabel(null, curator)).toBe('General');
    expect(interestCategoryLabel('', curator)).toBe('General');
  });
});
