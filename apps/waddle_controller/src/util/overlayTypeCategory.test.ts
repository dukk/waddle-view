import { describe, expect, it } from 'vitest';
import {
  OVERLAY_CATEGORY_EFFECT,
  OVERLAY_CATEGORY_WIDGET,
  defaultCreateOverlayType,
  groupOverlayTypesByCategory,
  overlayTypeCategory,
  overlayTypeRequiresPlacement,
  partitionOverlayRowsByCategory,
} from './overlayTypeCategory';
import type { OverlayTypeSchemaMeta } from '@/storage/configSchemaCache';

function meta(
  overlay_type: string,
  extra?: Partial<OverlayTypeSchemaMeta>,
): OverlayTypeSchemaMeta {
  return { overlay_type, ...extra };
}

describe('overlayTypeCategory', () => {
  it('prefers API category when present', () => {
    expect(
      overlayTypeCategory('static_image', { category: OVERLAY_CATEGORY_WIDGET }),
    ).toBe(OVERLAY_CATEGORY_WIDGET);
    expect(
      overlayTypeCategory('shape_rain', { category: OVERLAY_CATEGORY_EFFECT }),
    ).toBe(OVERLAY_CATEGORY_EFFECT);
  });

  it('falls back to builtin map', () => {
    expect(overlayTypeCategory('matrix_rain')).toBe(OVERLAY_CATEGORY_EFFECT);
    expect(overlayTypeCategory('digital_clock')).toBe(OVERLAY_CATEGORY_WIDGET);
    expect(overlayTypeRequiresPlacement('qr_code')).toBe(true);
    expect(overlayTypeRequiresPlacement('edge_glow')).toBe(false);
  });

  it('groups and partitions by category', () => {
    const types = [
      meta('qr_code', { label: 'QR code', category: 'widget' }),
      meta('shape_rain', { label: 'Shape rain', category: 'effect' }),
      meta('digital_clock', { label: 'Digital clock', category: 'widget' }),
    ];
    const grouped = groupOverlayTypesByCategory(types);
    expect(grouped.effects.map((m) => m.overlay_type)).toEqual(['shape_rain']);
    expect(grouped.widgets.map((m) => m.overlay_type)).toEqual([
      'digital_clock',
      'qr_code',
    ]);
    const rows = [
      { id: '1', overlay_type: 'shape_rain', label: 'A' },
      { id: '2', overlay_type: 'digital_clock', label: 'B' },
    ];
    const parts = partitionOverlayRowsByCategory(rows, types);
    expect(parts.effects).toHaveLength(1);
    expect(parts.widgets).toHaveLength(1);
  });

  it('default create type is first effect', () => {
    const types = [
      meta('qr_code', { category: 'widget' }),
      meta('birthday_confetti', { category: 'effect' }),
      meta('shape_rain', { category: 'effect' }),
    ];
    expect(defaultCreateOverlayType(types)).toBe('birthday_confetti');
  });
});
