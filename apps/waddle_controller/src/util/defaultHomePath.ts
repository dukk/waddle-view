import type { SavedDisplay } from '@/storage/displays';
import { hasAnyAdoptedDisplay } from '@/util/adoptedDisplays';

/** Route for `/` when the operator has at least one adopted display. */
export function defaultHomePath(
  displays: SavedDisplay[],
  isProgramsOnlyControllerUser: boolean,
): string {
  if (!hasAnyAdoptedDisplay(displays)) {
    return '/displays';
  }
  return isProgramsOnlyControllerUser ? '/programs' : '/curators';
}
