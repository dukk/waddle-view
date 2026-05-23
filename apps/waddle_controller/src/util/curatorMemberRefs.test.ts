import { describe, expect, it } from 'vitest';
import {
  curatorMemberRefsFromLists,
  splitCuratorMemberRefs,
} from './curatorMemberRefs';

describe('curatorMemberRefs', () => {
  it('splitCuratorMemberRefs handles strings and op objects', () => {
    expect(
      splitCuratorMemberRefs([
        'news',
        { id: 'photo', op: 'remove' },
        { id: 'weather', op: 'add' },
      ]),
    ).toEqual({
      add: ['news', 'weather'],
      remove: ['photo'],
    });
  });

  it('curatorMemberRefsFromLists round-trips lists', () => {
    expect(
      curatorMemberRefsFromLists({
        add: ['a'],
        remove: ['b'],
      }),
    ).toEqual([
      { id: 'a', op: 'add' },
      { id: 'b', op: 'remove' },
    ]);
  });
});
