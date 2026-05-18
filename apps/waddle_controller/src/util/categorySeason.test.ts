import { describe, expect, it } from 'vitest';
import { categorySeasonPayload, formatCategorySeason } from './categorySeason';

describe('categorySeasonPayload', () => {
  it('clears dates when not seasonal', () => {
    expect(
      categorySeasonPayload({
        is_seasonal: false,
        start_month: '12',
        start_day: '1',
        end_month: '12',
        end_day: '31',
      }),
    ).toEqual({
      start_month: null,
      start_day: null,
      end_month: null,
      end_day: null,
    });
  });

  it('returns payload when seasonal dates are valid', () => {
    expect(
      categorySeasonPayload({
        is_seasonal: true,
        start_month: '12',
        start_day: '1',
        end_month: '12',
        end_day: '31',
      }),
    ).toEqual({
      start_month: 12,
      start_day: 1,
      end_month: 12,
      end_day: 31,
    });
  });

  it('returns error when seasonal dates are incomplete', () => {
    expect(
      categorySeasonPayload({
        is_seasonal: true,
        start_month: '3',
        start_day: '',
        end_month: '4',
        end_day: '15',
      }),
    ).toMatch(/required/);
  });
});

describe('formatCategorySeason', () => {
  it('formats a season range', () => {
    expect(
      formatCategorySeason({
        is_seasonal: true,
        start_month: 12,
        start_day: 1,
        end_month: 12,
        end_day: 31,
      }),
    ).toBe('Dec 1 – Dec 31');
  });
});
