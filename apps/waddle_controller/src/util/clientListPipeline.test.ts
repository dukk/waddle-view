import { describe, expect, it } from 'vitest';
import {
  applyClientListPipeline,
  filterBySearch,
  normalizeSearchQuery,
  sortByOption,
  type SortOption,
} from './clientListPipeline';

type Row = { id: string; label: string };

const sortOptions: SortOption<Row>[] = [
  { id: 'id', label: 'ID', compare: (a, b) => a.id.localeCompare(b.id) },
  { id: 'label', label: 'Label', compare: (a, b) => a.label.localeCompare(b.label) },
];

describe('normalizeSearchQuery', () => {
  it('trims and lowercases', () => {
    expect(normalizeSearchQuery('  Foo ')).toBe('foo');
  });
});

describe('filterBySearch', () => {
  const rows: Row[] = [
    { id: 'a', label: 'Alpha' },
    { id: 'b', label: 'Beta' },
  ];

  it('returns all rows when query is empty', () => {
    expect(filterBySearch(rows, '', (r, q) => r.label.toLowerCase().includes(q))).toEqual(rows);
  });

  it('filters by predicate', () => {
    expect(
      filterBySearch(rows, 'alp', (r, q) => r.label.toLowerCase().includes(q)),
    ).toEqual([{ id: 'a', label: 'Alpha' }]);
  });
});

describe('sortByOption', () => {
  it('sorts without mutating input', () => {
    const input: Row[] = [
      { id: 'b', label: 'B' },
      { id: 'a', label: 'A' },
    ];
    const sorted = sortByOption(input, sortOptions[0]);
    expect(sorted.map((r) => r.id)).toEqual(['a', 'b']);
    expect(input.map((r) => r.id)).toEqual(['b', 'a']);
  });
});

describe('applyClientListPipeline', () => {
  const items: Row[] = [
    { id: 'z', label: 'Zulu' },
    { id: 'a', label: 'Alpha' },
    { id: 'm', label: 'Mike' },
  ];

  it('filters then sorts', () => {
    const out = applyClientListPipeline({
      items,
      search: 'a',
      searchMatches: (r, q) =>
        r.id.toLowerCase().includes(q) || r.label.toLowerCase().includes(q),
      sortOptions,
      sortId: 'label',
    });
    expect(out.map((r) => r.id)).toEqual(['a']);
  });
});
