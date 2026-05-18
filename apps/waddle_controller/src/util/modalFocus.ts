const kRootId = 'root';

/** True when [element] is a non-root descendant of `#root`. */
export function isFocusableWithinAppRoot(element: Element | null, root: Element | null): element is HTMLElement {
  return (
    element instanceof HTMLElement &&
    root instanceof HTMLElement &&
    element !== root &&
    root.contains(element)
  );
}

/**
 * Blur the active element when it lives under `#root` so MUI modals can mark the
 * app root `aria-hidden` without leaving focus on a hidden descendant.
 */
export function blurFocusedElementWithinAppRoot(
  activeElement: Element | null = document.activeElement,
  root: Element | null = document.getElementById(kRootId),
): boolean {
  if (!isFocusableWithinAppRoot(activeElement, root)) {
    return false;
  }
  activeElement.blur();
  return true;
}

/** Returns true when at least one MUI modal root is mounted. */
export function hasOpenMuiModal(modals: NodeListOf<Element> = document.querySelectorAll('.MuiModal-root')): boolean {
  return modals.length > 0;
}

/**
 * When a modal is open, blur any focused control still inside `#root`.
 * Intended for a parent `useLayoutEffect` so it runs before child modal effects.
 */
export function reconcileModalFocusWithAppRoot(
  activeElement: Element | null = document.activeElement,
  root: Element | null = document.getElementById(kRootId),
  modals: NodeListOf<Element> = document.querySelectorAll('.MuiModal-root'),
): boolean {
  if (!hasOpenMuiModal(modals)) {
    return false;
  }
  return blurFocusedElementWithinAppRoot(activeElement, root);
}
