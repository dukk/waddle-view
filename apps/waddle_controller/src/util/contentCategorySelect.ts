export type ContentCategoryOption = {
  id: string;
  label: string;
};

/** Resolves a stored category reference (id or label) to the display label for Select values. */
export function resolveCategoryLabel(
  stored: string,
  categories: ContentCategoryOption[],
): string {
  const t = stored.trim();
  if (!t) return '';
  const byLabel = categories.find((c) => c.label === t);
  if (byLabel) return byLabel.label;
  const byId = categories.find((c) => c.id === t);
  if (byId) return byId.label;
  return t;
}

/** Resolves stored category references to display labels (deduped, order preserved). */
export function resolveCategoryLabels(
  stored: string[],
  categories: ContentCategoryOption[],
): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const raw of stored) {
    if (typeof raw !== 'string' || !raw.trim()) continue;
    const label = resolveCategoryLabel(raw, categories);
    if (!label || seen.has(label)) continue;
    seen.add(label);
    out.push(label);
  }
  return out;
}

/** Reads category filter field(s) from screen/overlay config_json. */
export function categoryLabelsForConfig(
  config: Record<string, unknown>,
  categories: ContentCategoryOption[],
): string[] {
  const names = config.categoryNames;
  if (Array.isArray(names) && names.length > 0) {
    return resolveCategoryLabels(
      names.filter((x): x is string => typeof x === 'string'),
      categories,
    );
  }
  const single = config.categoryName;
  if (typeof single === 'string' && single.trim()) {
    const label = resolveCategoryLabel(single, categories);
    return label ? [label] : [];
  }
  return [];
}

/** Normalizes category fields in config to display labels for controller pickers. */
export function normalizeConfigCategoryFields(
  config: Record<string, unknown>,
  categories: ContentCategoryOption[],
): Record<string, unknown> {
  const out = { ...config };
  if (typeof out.categoryName === 'string' && out.categoryName.trim()) {
    const label = resolveCategoryLabel(out.categoryName, categories);
    if (label) out.categoryName = label;
  }
  if (Array.isArray(out.categoryNames) && out.categoryNames.length > 0) {
    const labels = resolveCategoryLabels(
      out.categoryNames.filter((x): x is string => typeof x === 'string'),
      categories,
    );
    if (labels.length > 0) out.categoryNames = labels;
  }
  return out;
}
