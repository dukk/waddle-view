import { slugifyInterestSource, uniqueInterestSlug } from '@/util/interestSlug';

/** Derives a stable account id slug from an operator-entered display name. */
export function integrationAccountIdFromName(
  name: string,
  existingIds: Iterable<string>,
): string {
  return uniqueInterestSlug(slugifyInterestSource(name), existingIds);
}
