import type { OverlayTypeSchemaMeta } from '@/storage/configSchemaCache';

const FALLBACK_LABELS: Record<string, string> = {
  shape_rain: 'Shape rain',
  birthday_confetti: 'Birthday confetti',
  bouncing_message: 'Bouncing message',
  falling_images: 'Falling images',
  matrix_rain: 'Matrix rain',
  edge_glow: 'Edge glow',
  floating_balloons: 'Floating balloons',
  static_image: 'Static image',
  digital_clock: 'Digital clock',
  analog_clock: 'Analog clock',
  calendar_month: 'Calendar month',
  calendar_upcoming: 'Calendar upcoming',
  stock_quote: 'Stock quote',
  photo_slideshow: 'Photo slideshow',
};

/** Human-facing label for an overlay type (registry label when available). */
export function overlayTypeLabel(
  overlayType: string | null | undefined,
  meta?: OverlayTypeSchemaMeta | null,
): string {
  const normalized = (overlayType ?? '').trim();
  if (!normalized) return 'unknown';
  const fromLabel = meta?.label?.trim();
  if (fromLabel) return fromLabel;
  return FALLBACK_LABELS[normalized] ?? normalized.replace(/_/g, ' ');
}

export function overlayTypeMetaFor(
  overlayTypes: OverlayTypeSchemaMeta[],
  overlayType: string,
): OverlayTypeSchemaMeta | undefined {
  return overlayTypes.find((m) => m.overlay_type === overlayType);
}
