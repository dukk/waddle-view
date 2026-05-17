import type { SavedDisplay } from '@/storage/displays';
import { loadSession } from '@/storage/sessions';

export function hasAnyAdoptedDisplay(displays: SavedDisplay[]): boolean {
  return displays.some((d) => loadSession(d.id) != null);
}
