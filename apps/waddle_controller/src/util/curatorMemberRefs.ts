export type CuratorMemberOp = 'add' | 'remove';

export type CuratorMemberRef =
  | string
  | {
      id: string;
      op?: CuratorMemberOp;
    };

export type CuratorMemberLists = {
  add: string[];
  remove: string[];
};

export function splitCuratorMemberRefs(refs: CuratorMemberRef[] | undefined): CuratorMemberLists {
  const add: string[] = [];
  const remove: string[] = [];
  for (const ref of refs ?? []) {
    if (typeof ref === 'string') {
      const id = ref.trim();
      if (id) add.push(id);
      continue;
    }
    const id = ref.id.trim();
    if (!id) continue;
    if (ref.op === 'remove') {
      remove.push(id);
    } else {
      add.push(id);
    }
  }
  return { add, remove };
}

export function curatorMemberRefsFromLists(lists: CuratorMemberLists): CuratorMemberRef[] {
  return [
    ...lists.add.map((id) => ({ id, op: 'add' as const })),
    ...lists.remove.map((id) => ({ id, op: 'remove' as const })),
  ];
}
