const CATALOG_ID_RE = /^[a-zA-Z][a-zA-Z0-9_-]{0,62}$/;

/** Returns an error message when [id] is not a valid catalog id, else null. */
export function validateCatalogId(id: string): string | null {
  const trimmed = id.trim();
  if (!trimmed) {
    return 'Id is required.';
  }
  if (!CATALOG_ID_RE.test(trimmed)) {
    return 'Id must start with a letter and use only letters, numbers, underscores, and hyphens (max 63 characters).';
  }
  return null;
}
