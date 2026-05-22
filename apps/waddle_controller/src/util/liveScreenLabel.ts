import { buildSlideCardModel } from '@/util/programTelemetry';
import { screenTypeLabel } from '@/util/screenTypeLabel';

export function asRecordArray(v: unknown): Record<string, unknown>[] {
  if (!Array.isArray(v)) return [];
  return v.filter(
    (x): x is Record<string, unknown> =>
      x != null && typeof x === 'object' && !Array.isArray(x),
  );
}

export type NowPlayingInfo = {
  summary: string;
  screenIds: string[];
};

export function liveScreenLabelFromProgram(
  row: Record<string, unknown>,
  options?: {
    screenLabelById?: ReadonlyMap<string, string>;
    screenTypeDisplayLabel?: (screenType: string) => string;
  },
): NowPlayingInfo | null {
  const slides = asRecordArray(row['slides']);
  if (slides.length === 0) return null;

  const typeLabel =
    options?.screenTypeDisplayLabel ?? ((st: string) => screenTypeLabel(st, undefined));
  const parts: string[] = [];
  const screenIds: string[] = [];

  for (let i = 0; i < slides.length; i++) {
    const model = buildSlideCardModel(slides[i]!, i);
    screenIds.push(model.screenId);
    const catalogLabel = options?.screenLabelById?.get(model.screenId);
    const type = model.screenType ? typeLabel(model.screenType) : 'slide';
    if (catalogLabel) {
      parts.push(catalogLabel);
    } else if (model.screenId) {
      parts.push(`${model.screenId} (${type})`);
    } else {
      parts.push(type);
    }
  }

  if (slides.length === 1) {
    return { summary: parts[0]!, screenIds };
  }
  return { summary: `Rotation: ${parts.join(', ')}`, screenIds };
}
