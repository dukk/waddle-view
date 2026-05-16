export type RandomChoices = Record<string, string>;

export type LayoutWidget = {
  type: string;
  slot: string;
  config: Record<string, unknown>;
};

function extractWidgets(doc: Record<string, unknown>): LayoutWidget[] {
  const raw = doc['widgets'];
  if (!Array.isArray(raw)) return [];
  const out: LayoutWidget[] = [];
  for (const e of raw) {
    if (!e || typeof e !== 'object') continue;
    const m = e as Record<string, unknown>;
    const type = m['type'];
    const slot = m['slot'];
    if (typeof type !== 'string' || typeof slot !== 'string') continue;
    const cfg = m['config'];
    const config =
      cfg && typeof cfg === 'object' && !Array.isArray(cfg)
        ? (cfg as Record<string, unknown>)
        : {};
    out.push({ type, slot, config });
  }
  return out;
}

export function parseLayoutWidgets(layoutJson: unknown): LayoutWidget[] {
  if (typeof layoutJson === 'string') {
    try {
      const decoded = JSON.parse(layoutJson) as unknown;
      if (!decoded || typeof decoded !== 'object') return [];
      return extractWidgets(decoded as Record<string, unknown>);
    } catch {
      return [];
    }
  }
  if (!layoutJson || typeof layoutJson !== 'object') return [];
  return extractWidgets(layoutJson as Record<string, unknown>);
}

export function formatDwell(ms: unknown): string {
  const n = typeof ms === 'number' ? ms : Number(ms);
  if (!Number.isFinite(n) || n <= 0) return '—';
  if (n < 1000) return `${Math.round(n)} ms`;
  const s = n / 1000;
  if (s < 60) return `${s % 1 === 0 ? s : s.toFixed(1)} s`;
  const m = Math.floor(s / 60);
  const rs = s - m * 60;
  return `${m}m ${rs < 10 ? '0' : ''}${Math.round(rs)}s`;
}

export function programTimestamp(atMs: unknown): string {
  const n = typeof atMs === 'number' ? atMs : Number(atMs);
  if (!Number.isFinite(n)) return 'Unknown time';
  return new Date(n).toLocaleString(undefined, {
    dateStyle: 'medium',
    timeStyle: 'medium',
  });
}

function str(v: unknown): string {
  if (typeof v === 'string') return v;
  if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  return '';
}

function summarizeWidget(
  w: LayoutWidget,
  choices: RandomChoices,
): { headline: string; sub?: string } {
  const ck = `${w.slot}_${w.type}`;
  const curated = choices[ck];
  switch (w.type) {
    case 'static_text':
      return { headline: str(w.config['text']) || '(empty text)', sub: 'Static text' };
    case 'weather': {
      const loc = str(w.config['locationId'] ?? w.config['location_id']);
      return { headline: loc ? `Weather · ${loc}` : 'Weather', sub: 'Current conditions' };
    }
    case 'rss_article':
      return {
        headline: curated ? `RSS article (${curated})` : 'RSS article · auto pick',
        sub: str(w.config['feedId'] ?? w.config['feed_id'])
          ? `Feed ${str(w.config['feedId'] ?? w.config['feed_id'])}`
          : undefined,
      };
    case 'rss_article_columns':
      return {
        headline: 'RSS columns',
        sub: curated ? `Primary article ${curated}` : undefined,
      };
    case 'rss_article_stack':
      return {
        headline: 'RSS stack',
        sub: curated ? `Article ${curated}` : undefined,
      };
    case 'pexels_photo':
      return {
        headline: curated ? `Photo · ${curated}` : 'Pexels photo',
        sub: str(w.config['query']) ? `Query: ${str(w.config['query'])}` : undefined,
      };
    case 'pexels_photo_collage':
      return { headline: 'Photo collage', sub: 'Multiple slots' };
    case 'pexels_video':
      return { headline: curated ? `Video · ${curated}` : 'Pexels video' };
    case 'joke':
      return {
        headline: curated ? `Joke · ${curated}` : 'Joke',
        sub: str(w.config['categoryId'] ?? w.config['category_id']) || undefined,
      };
    case 'trivia':
      return { headline: curated ? `Trivia · ${curated}` : 'Trivia' };
    case 'stock_quotes': {
      const sym = w.config['symbols'];
      const part = Array.isArray(sym)
        ? (sym as unknown[]).filter((x) => typeof x === 'string').join(', ')
        : str(sym);
      return { headline: part ? `Stocks · ${part}` : 'Stock quotes' };
    }
    case 'data_health':
      return { headline: 'Data health' };
    case 'calendar_month':
      return { headline: 'Calendar', sub: str(w.config['title']) || undefined };
    case 'bing_image_of_day':
      return { headline: 'Bing image of the day', sub: curated ? `Pick ${curated}` : undefined };
    default:
      return { headline: curated ? `${w.type} · ${curated}` : w.type };
  }
}

export type SlideSummaryLine = {
  headline: string;
  sub?: string;
  type: string;
  slot: string;
};

export type SlideCardModel = {
  index: number;
  screenId: string;
  screenType: string | null;
  dwellLabel: string;
  dwellMs: number;
  widgets: LayoutWidget[];
  summaries: SlideSummaryLine[];
  layoutJsonRaw: string;
  randomChoices: RandomChoices;
};

export function buildSlideCardModel(slide: Record<string, unknown>, index: number): SlideCardModel {
  const screenId = String(slide['screen_id'] ?? '');
  const screenType = slide['screen_type'] == null ? null : String(slide['screen_type']);
  const dwellMs =
    typeof slide['dwell_ms'] === 'number' ? slide['dwell_ms'] : Number(slide['dwell_ms']) || 0;
  const lj = slide['layout_json'];
  const raw = typeof lj === 'string' ? lj : JSON.stringify(lj ?? '');
  const widgets = parseLayoutWidgets(lj);
  const rcRaw = slide['random_choices'];
  const randomChoices: RandomChoices =
    rcRaw && typeof rcRaw === 'object' && !Array.isArray(rcRaw)
      ? Object.fromEntries(
          Object.entries(rcRaw as Record<string, unknown>).map(([k, v]) => [
            k,
            v == null ? '' : String(v),
          ]),
        )
      : {};
  const summaries = widgets.map((w) => {
    const s = summarizeWidget(w, randomChoices);
    return { ...s, type: w.type, slot: w.slot };
  });
  return {
    index,
    screenId,
    screenType,
    dwellLabel: formatDwell(dwellMs),
    dwellMs,
    widgets,
    summaries,
    layoutJsonRaw: raw,
    randomChoices,
  };
}

export function tickerTapeSummary(item: Record<string, unknown>): string {
  const kind = String(item['kind'] ?? '');
  const rss = item['rss'];
  if (rss && typeof rss === 'object') {
    const r = rss as Record<string, unknown>;
    const title = str(r['article_title']);
    if (title) return `${kind}: ${title}`;
  }
  const body = String(item['body'] ?? '');
  if (body.length > 140) return `${kind}: ${body.slice(0, 137)}…`;
  return `${kind}: ${body}`;
}

export function collectSlideContentIds(model: SlideCardModel): {
  rssArticleIds: string[];
  photoIds: string[];
  videoIds: string[];
  jokeIds: string[];
  triviaIds: string[];
} {
  const rssArticleIds: string[] = [];
  const photoIds: string[] = [];
  const videoIds: string[] = [];
  const jokeIds: string[] = [];
  const triviaIds: string[] = [];

  for (const w of model.widgets) {
    const choiceKey = `${w.slot}_${w.type}`;
    if (w.type === 'rss_article' || w.type === 'rss_article_columns' || w.type === 'rss_article_stack') {
      const id = model.randomChoices[choiceKey];
      if (id) rssArticleIds.push(id);
      if (w.type === 'rss_article_columns' || w.type === 'rss_article_stack') {
        for (let i = 0; i < 12; i++) {
          const slotId = model.randomChoices[`${choiceKey}_${i}`];
          if (slotId) rssArticleIds.push(slotId);
        }
      }
    }
    if (w.type === 'pexels_photo') {
      const id = model.randomChoices[choiceKey];
      if (id) photoIds.push(id);
    }
    if (w.type === 'pexels_photo_collage') {
      for (let i = 0; i < 12; i++) {
        const pid = model.randomChoices[`${choiceKey}_${i}`];
        if (pid) photoIds.push(pid);
      }
    }
    if (w.type === 'pexels_video') {
      const id = model.randomChoices[choiceKey];
      if (id) videoIds.push(id);
    }
    if (w.type === 'joke') {
      const id = model.randomChoices[choiceKey];
      if (id) jokeIds.push(id);
    }
    if (w.type === 'trivia') {
      const id = model.randomChoices[choiceKey];
      if (id) triviaIds.push(id);
    }
  }

  const uniq = (xs: string[]) => [...new Set(xs.filter((x) => x.length > 0))];
  return {
    rssArticleIds: uniq(rssArticleIds),
    photoIds: uniq(photoIds),
    videoIds: uniq(videoIds),
    jokeIds: uniq(jokeIds),
    triviaIds: uniq(triviaIds),
  };
}

/** Enabled weather_locations.id values referenced by weather widgets on this slide. */
export function collectWeatherLocationIds(model: SlideCardModel): string[] {
  const ids: string[] = [];
  for (const w of model.widgets) {
    if (w.type === 'weather') {
      const loc = str(w.config['locationId'] ?? w.config['location_id']);
      if (loc) ids.push(loc);
    }
  }
  return [...new Set(ids.filter((x) => x.length > 0))];
}
