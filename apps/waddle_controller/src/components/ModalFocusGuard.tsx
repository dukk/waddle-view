import { useLayoutEffect } from 'react';
import { reconcileModalFocusWithAppRoot } from '@/util/modalFocus';

/** Keeps MUI modal `aria-hidden` on `#root` from conflicting with retained trigger focus. */
export function ModalFocusGuard() {
  useLayoutEffect(() => {
    reconcileModalFocusWithAppRoot();
  });

  return null;
}
