import { describe, expect, it } from 'vitest';
import { paginateList } from './listPagination';

describe('paginateList', () => {
  it('returns the requested page slice', () => {
    const all = [1, 2, 3, 4, 5, 6, 7];
    expect(paginateList(all, 0, 3)).toMatchObject({
      items: [1, 2, 3],
      total: 7,
      page: 0,
      pageCount: 3,
    });
    expect(paginateList(all, 1, 3)).toMatchObject({
      items: [4, 5, 6],
      page: 1,
    });
    expect(paginateList(all, 2, 3)).toMatchObject({
      items: [7],
      page: 2,
    });
  });

  it('clamps page when the list is shorter', () => {
    expect(paginateList([1, 2, 3], 5, 2)).toMatchObject({
      items: [3],
      page: 1,
      pageCount: 2,
    });
  });
});
