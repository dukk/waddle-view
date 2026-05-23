import { describe, expect, it } from 'vitest';
import {
  applySortOrder,
  buildColumnSortOptions,
  columnSortToolbarOptions,
  compareBool,
  compareLocale,
  compareNumber,
  tieBreakLocale,
} from './dataViewColumnSort';
import { applyClientListPipeline } from './clientListPipeline';

type Row = { id: string; n: number };

describe('compare helpers', () => {
  it('compareLocale is case-insensitive base', () => {
    expect(compareLocale('b', 'A')).toBeGreaterThan(0);
  });

  it('compareNumber and compareBool', () => {
    expect(compareNumber(2, 1)).toBe(1);
    expect(compareBool(true, false)).toBe(1);
  });

  it('applySortOrder inverts', () => {
    expect(applySortOrder(5, 'desc')).toBe(-5);
    expect(applySortOrder(5, 'asc')).toBe(5);
  });

  it('tieBreakLocale uses id when primary ties', () => {
    expect(tieBreakLocale(0, 'b', 'a')).toBeGreaterThan(0);
    expect(tieBreakLocale(1, 'a', 'b')).toBe(1);
  });
});

describe('buildColumnSortOptions', () => {
  const fields = [
    { id: 'n', label: 'N', compare: (a: Row, b: Row) => compareNumber(a.n, b.n) },
  ] as const;

  it('maps fields to sort options', () => {
    const opts = buildColumnSortOptions(fields);
    expect(opts[0]?.id).toBe('n');
    expect(columnSortToolbarOptions(fields)).toEqual([{ id: 'n', label: 'N' }]);
  });
});

describe('applyClientListPipeline with order', () => {
  const items: Row[] = [
    { id: 'a', n: 1 },
    { id: 'b', n: 3 },
    { id: 'c', n: 2 },
  ];
  const sortOptions = buildColumnSortOptions([
    { id: 'n', label: 'N', compare: (a, b) => compareNumber(a.n, b.n) },
  ]);

  it('sorts desc when order is desc', () => {
    const out = applyClientListPipeline({
      items,
      search: '',
      searchMatches: () => true,
      sortOptions,
      sortId: 'n',
      order: 'desc',
    });
    expect(out.map((r) => r.n)).toEqual([3, 2, 1]);
  });
});
