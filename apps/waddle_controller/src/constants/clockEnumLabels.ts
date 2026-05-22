/** Keep in sync with kAnalogDialLabelsEnumLabels / kAnalogHandAccentEnumLabels in waddle_shared. */

export const ANALOG_DIAL_LABELS_OPTIONS: readonly { value: string; label: string }[] = [
  { value: 'none', label: 'None' },
  { value: 'numbers', label: 'Hour numbers (1–12)' },
  { value: 'numeric', label: 'Hour numbers (1–12)' },
  { value: 'roman', label: 'Roman numerals' },
  { value: 'roman_numerals', label: 'Roman numerals' },
  { value: 'cardinal_numbers', label: 'Cardinal (12, 3, 6, 9)' },
  { value: 'cardinal', label: 'Cardinal (12, 3, 6, 9)' },
  { value: 'crosshair_numbers', label: 'Cardinal (12, 3, 6, 9)' },
];

export const THEME_ACCENT_OPTIONS: readonly { value: string; label: string; accentIndex: number }[] = [
  { value: 'accent1', label: 'Accent 1', accentIndex: 0 },
  { value: 'accent2', label: 'Accent 2', accentIndex: 1 },
  { value: 'accent3', label: 'Accent 3', accentIndex: 2 },
  { value: '1', label: 'Accent 1', accentIndex: 0 },
  { value: '2', label: 'Accent 2', accentIndex: 1 },
  { value: '3', label: 'Accent 3', accentIndex: 2 },
];

export const NEWS_QR_MODE_OPTIONS: readonly { value: string; label: string }[] = [
  { value: 'hidden', label: 'Hidden' },
  { value: 'left', label: 'Left of article text' },
  { value: 'right', label: 'Right of article text' },
  { value: 'image_overlay_bottom', label: 'Over bottom of article image' },
];

export const NEWS_IMAGE_FIT_OPTIONS: readonly { value: string; label: string }[] = [
  { value: 'cover', label: 'Fill (crop)' },
  { value: 'contain', label: 'Actual size (letterbox)' },
  { value: 'fill', label: 'Stretch' },
  { value: 'fitWidth', label: 'Fit width' },
  { value: 'fitHeight', label: 'Fit height' },
  { value: 'scaleDown', label: 'Scale down only' },
];

export const INVITE_ROLE_OPTIONS: readonly { value: string; label: string }[] = [
  { value: 'viewer', label: 'Viewer' },
  { value: 'power_viewer', label: 'Power viewer' },
  { value: 'operator', label: 'Operator' },
  { value: 'admin', label: 'Admin' },
];

export function enumLabelForValue(
  options: readonly { value: string; label: string }[],
  value: string,
): string {
  return options.find((o) => o.value === value)?.label ?? value;
}

export function readEnumLabelsFromSchema(schema: Record<string, unknown>): Record<string, string> | null {
  const raw = schema['x-waddle-enum-labels'];
  if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) {
    return null;
  }
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(raw)) {
    if (typeof v === 'string') {
      out[k] = v;
    }
  }
  return Object.keys(out).length > 0 ? out : null;
}
