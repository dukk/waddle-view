import {
  categoryLabelsForConfig,
  type ContentCategoryOption,
} from '@/util/contentCategorySelect';
import { parseJsonObject } from '@/util/json';

export function formatPlacementsSummary(
  min: number,
  max: number | null | undefined,
): string {
  const minN = Math.max(0, Math.round(min));
  if (max == null || max <= 0) {
    return `${minN}–∞`;
  }
  return `${minN}–${Math.round(max)}`;
}

export function formatCategoriesSummary(
  configJson: string,
  categories: ContentCategoryOption[],
): string {
  const config = parseJsonObject(configJson);
  const labels = categoryLabelsForConfig(config, categories);
  if (labels.length === 0) return '—';
  return labels.join(', ');
}

export function screenListSchedulingSummary(
  row: {
    config_json: string;
    min_placements_per_program: number;
    max_placements_per_program?: number | null;
  },
  categories: ContentCategoryOption[],
): { categories: string; placements: string } {
  return {
    categories: formatCategoriesSummary(row.config_json, categories),
    placements: formatPlacementsSummary(
      row.min_placements_per_program,
      row.max_placements_per_program,
    ),
  };
}
