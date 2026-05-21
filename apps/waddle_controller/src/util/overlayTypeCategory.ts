import type { OverlayTypeSchemaMeta } from '@/storage/configSchemaCache';
import { overlayTypeLabel } from '@/util/overlayTypeLabel';

export const OVERLAY_CATEGORY_EFFECT = 'effect' as const;
export const OVERLAY_CATEGORY_WIDGET = 'widget' as const;

export type OverlayCategory = typeof OVERLAY_CATEGORY_EFFECT | typeof OVERLAY_CATEGORY_WIDGET;

const EFFECT_TYPES = new Set([
  'shape_rain',
  'hearts_rain',
  'birthday_confetti',
  'bouncing_message',
  'falling_images',
  'matrix_rain',
  'edge_glow',
  'floating_balloons',
  'cloud_drift',
]);

const WIDGET_TYPES = new Set([
  'static_image',
  'photo_slideshow',
  'digital_clock',
  'analog_clock',
  'calendar_month',
  'calendar_upcoming',
  'stock_quote',
  'qr_code',
]);

export function overlayTypeCategory(
  overlayType: string,
  meta?: Pick<OverlayTypeSchemaMeta, 'category'> | null,
): OverlayCategory {
  const fromMeta = meta?.category;
  if (fromMeta === OVERLAY_CATEGORY_EFFECT || fromMeta === OVERLAY_CATEGORY_WIDGET) {
    return fromMeta;
  }
  const key = overlayType.trim();
  if (EFFECT_TYPES.has(key)) return OVERLAY_CATEGORY_EFFECT;
  if (WIDGET_TYPES.has(key)) return OVERLAY_CATEGORY_WIDGET;
  return OVERLAY_CATEGORY_EFFECT;
}

export function overlayTypeRequiresPlacement(
  overlayType: string,
  meta?: Pick<OverlayTypeSchemaMeta, 'category' | 'requires_placement'> | null,
): boolean {
  if (meta?.requires_placement === true) return true;
  if (meta?.requires_placement === false) return false;
  return overlayTypeCategory(overlayType, meta) === OVERLAY_CATEGORY_WIDGET;
}

function sortByTypeLabel(
  a: OverlayTypeSchemaMeta,
  b: OverlayTypeSchemaMeta,
): number {
  const labelA = overlayTypeLabel(a.overlay_type, a);
  const labelB = overlayTypeLabel(b.overlay_type, b);
  return labelA.localeCompare(labelB);
}

export function groupOverlayTypesByCategory(overlayTypes: OverlayTypeSchemaMeta[]): {
  effects: OverlayTypeSchemaMeta[];
  widgets: OverlayTypeSchemaMeta[];
} {
  const effects: OverlayTypeSchemaMeta[] = [];
  const widgets: OverlayTypeSchemaMeta[] = [];
  for (const meta of overlayTypes) {
    if (overlayTypeCategory(meta.overlay_type, meta) === OVERLAY_CATEGORY_WIDGET) {
      widgets.push(meta);
    } else {
      effects.push(meta);
    }
  }
  effects.sort(sortByTypeLabel);
  widgets.sort(sortByTypeLabel);
  return { effects, widgets };
}

export function overlayCategoryLabel(category: OverlayCategory): string {
  return category === OVERLAY_CATEGORY_WIDGET ? 'Widget' : 'Effect';
}

export type OverlayRowLike = { overlay_type: string };

export function partitionOverlayRowsByCategory<T extends OverlayRowLike>(
  rows: T[],
  overlayTypes: OverlayTypeSchemaMeta[],
): { effects: T[]; widgets: T[] } {
  const metaFor = (type: string) =>
    overlayTypes.find((m) => m.overlay_type === type) ?? null;
  const effects: T[] = [];
  const widgets: T[] = [];
  for (const row of rows) {
    const meta = metaFor(row.overlay_type);
    if (overlayTypeCategory(row.overlay_type, meta) === OVERLAY_CATEGORY_WIDGET) {
      widgets.push(row);
    } else {
      effects.push(row);
    }
  }
  return { effects, widgets };
}

export function defaultCreateOverlayType(overlayTypes: OverlayTypeSchemaMeta[]): string {
  const { effects } = groupOverlayTypesByCategory(overlayTypes);
  return effects[0]?.overlay_type ?? overlayTypes[0]?.overlay_type ?? 'shape_rain';
}
