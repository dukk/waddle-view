import { useCallback, useState } from 'react';
import {
  readListLayoutPreference,
  writeListLayoutPreference,
  type ListLayoutMode,
  type ListLayoutPageKey,
} from '@/storage/listLayoutPreference';

export function useListLayoutPreference(page: ListLayoutPageKey): {
  layout: ListLayoutMode;
  setLayout: (value: ListLayoutMode) => void;
} {
  const [layout, setLayoutState] = useState<ListLayoutMode>(() => readListLayoutPreference(page));

  const setLayout = useCallback(
    (value: ListLayoutMode) => {
      setLayoutState(value);
      writeListLayoutPreference(page, value);
    },
    [page],
  );

  return { layout, setLayout };
}
