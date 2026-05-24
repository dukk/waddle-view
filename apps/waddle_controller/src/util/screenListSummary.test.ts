import { describe, expect, it } from 'vitest';
import {
  formatCategoriesSummary,
  formatPlacementsSummary,
  screenListSchedulingSummary,
} from '@/util/screenListSummary';

const categories = [{ id: 'general', label: 'General' }];

describe('formatPlacementsSummary', () => {
  it('shows open-ended max', () => {
    expect(formatPlacementsSummary(1, null)).toBe('1–∞');
  });

  it('shows capped max', () => {
    expect(formatPlacementsSummary(0, 3)).toBe('0–3');
  });
});

describe('formatCategoriesSummary', () => {
  it('returns em dash when empty', () => {
    expect(formatCategoriesSummary('{}', categories)).toBe('—');
  });

  it('resolves category id in config', () => {
    expect(formatCategoriesSummary('{"categoryName":"general"}', categories)).toBe('General');
  });
});

describe('screenListSchedulingSummary', () => {
  it('combines categories and placements', () => {
    expect(
      screenListSchedulingSummary(
        {
          config_json: '{"categoryName":"general"}',
          min_placements_per_program: 0,
          max_placements_per_program: 2,
        },
        categories,
      ),
    ).toEqual({ categories: 'General', placements: '0–2' });
  });
});
