import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  Chip,
  Collapse,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  IconButton,
  Link,
  Paper,
  Snackbar,
  Stack,
  Tooltip,
  Typography,
} from '@mui/material';
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp';
import KeyboardArrowLeftIcon from '@mui/icons-material/KeyboardArrowLeft';
import KeyboardArrowRightIcon from '@mui/icons-material/KeyboardArrowRight';
import { useDisplay } from '@/context/DisplayContext';
import { useAuth } from '@/context/AuthContext';
import { apiFetch, apiJson, ApiError, fetchBlobObjectUrl } from '@/api/client';
import { NoDisplayPlaceholder } from '@/components/NoDisplayPlaceholder';
import { SlideProgramCard } from '@/components/SlideProgramCard';
import { TickerProgramCard } from '@/components/TickerProgramCard';
import type { SavedDisplay } from '@/storage/displays';
import {
  buildSlideCardModel,
  collectSlideContentIds,
  collectWeatherLocationIds,
  programTimestamp,
  type SlideCardModel,
} from '@/util/programTelemetry';

type Items<T> = { items: T[] };

function asRecordArray(v: unknown): Record<string, unknown>[] {
  if (!Array.isArray(v)) return [];
  return v.filter((x) => x && typeof x === 'object') as Record<string, unknown>[];
}

type RssArticleMedia = {
  id: string;
  title: string;
  summary?: string | null;
  link: string;
  image_blob_key?: string | null;
  feed_id?: string;
};

type PhotoMedia = {
  id: string;
  alt_text?: string;
  photographer_name?: string;
  pexels_page_url?: string;
  media_blob_key?: string;
};

type VideoMedia = {
  id: string;
  alt_text?: string;
  photographer_name?: string;
  pexels_page_url?: string;
  media_blob_key?: string;
  duration_seconds?: number;
};

type JokeMedia = {
  id: string;
  setup: string;
  punchline: string;
};

type TriviaMedia = {
  id: string;
  question: string;
  option_a: string;
  option_b: string;
  option_c: string;
  option_d: string;
  correct_option: string;
};

type WeatherAtLocationMedia = {
  location_id: string;
  location_name: string;
  current_temp_c?: number | null;
  current_description?: string | null;
  current_icon_blob_key?: string | null;
};

function cfgStr(config: Record<string, unknown>, a: string, b: string): string {
  const v = config[a] ?? config[b];
  if (typeof v === 'string') return v;
  if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  return '';
}

function SlideTelemetryDetail({
  display,
  model,
  open,
  onClose,
  slideIndex,
  slideCount,
  onPrevSlide,
  onNextSlide,
}: {
  display: SavedDisplay;
  model: SlideCardModel | null;
  open: boolean;
  onClose: () => void;
  slideIndex: number;
  slideCount: number;
  onPrevSlide: () => void;
  onNextSlide: () => void;
}) {
  const [rawOpen, setRawOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [rssById, setRssById] = useState<Record<string, RssArticleMedia>>({});
  const [photoById, setPhotoById] = useState<Record<string, PhotoMedia>>({});
  const [videoById, setVideoById] = useState<Record<string, VideoMedia>>({});
  const [jokeById, setJokeById] = useState<Record<string, JokeMedia>>({});
  const [triviaById, setTriviaById] = useState<Record<string, TriviaMedia>>({});
  const [weatherById, setWeatherById] = useState<Record<string, WeatherAtLocationMedia>>({});
  const [blobUrls, setBlobUrls] = useState<Record<string, string>>({});

  useEffect(() => {
    if (!open || !model) return;
    setRawOpen(false);
    setErr(null);
    setRssById({});
    setPhotoById({});
    setVideoById({});
    setJokeById({});
    setTriviaById({});
    setWeatherById({});
    setBlobUrls({});
    const objectUrls: string[] = [];
    let cancelled = false;
    (async () => {
      setLoading(true);
      try {
        const { rssArticleIds, photoIds, videoIds, jokeIds, triviaIds } = collectSlideContentIds(model);
        const weatherIds = collectWeatherLocationIds(model);
        const [rssRows, photoRows, videoRows, jokeRows, triviaRows, wxRows] = await Promise.all([
          Promise.all(
            rssArticleIds.map(async (id) => {
              try {
                const row = await apiJson<RssArticleMedia>(
                  display,
                  `/v1/media/rss-articles/${encodeURIComponent(id)}`,
                );
                return [id, row] as const;
              } catch {
                return null;
              }
            }),
          ),
          Promise.all(
            photoIds.map(async (id) => {
              try {
                const row = await apiJson<PhotoMedia>(
                  display,
                  `/v1/media/photos/${encodeURIComponent(id)}`,
                );
                return [id, row] as const;
              } catch {
                return null;
              }
            }),
          ),
          Promise.all(
            videoIds.map(async (id) => {
              try {
                const row = await apiJson<VideoMedia>(
                  display,
                  `/v1/media/videos/${encodeURIComponent(id)}`,
                );
                return [id, row] as const;
              } catch {
                return null;
              }
            }),
          ),
          Promise.all(
            jokeIds.map(async (id) => {
              try {
                const row = await apiJson<JokeMedia>(
                  display,
                  `/v1/media/jokes/${encodeURIComponent(id)}`,
                );
                return [id, row] as const;
              } catch {
                return null;
              }
            }),
          ),
          Promise.all(
            triviaIds.map(async (id) => {
              try {
                const row = await apiJson<TriviaMedia>(
                  display,
                  `/v1/media/trivia/${encodeURIComponent(id)}`,
                );
                return [id, row] as const;
              } catch {
                return null;
              }
            }),
          ),
          Promise.all(
            weatherIds.map(async (wid) => {
              try {
                const row = await apiJson<WeatherAtLocationMedia>(
                  display,
                  `/v1/media/weather-at-location/${encodeURIComponent(wid)}`,
                );
                return [wid, row] as const;
              } catch {
                return null;
              }
            }),
          ),
        ]);
        if (cancelled) return;
        setRssById(Object.fromEntries(rssRows.filter(Boolean) as [string, RssArticleMedia][]));
        setPhotoById(Object.fromEntries(photoRows.filter(Boolean) as [string, PhotoMedia][]));
        setVideoById(Object.fromEntries(videoRows.filter(Boolean) as [string, VideoMedia][]));
        setJokeById(Object.fromEntries(jokeRows.filter(Boolean) as [string, JokeMedia][]));
        setTriviaById(Object.fromEntries(triviaRows.filter(Boolean) as [string, TriviaMedia][]));
        setWeatherById(Object.fromEntries(wxRows.filter(Boolean) as [string, WeatherAtLocationMedia][]));

        const blobKeys = new Set<string>();
        for (const r of Object.values(
          Object.fromEntries(rssRows.filter(Boolean) as [string, RssArticleMedia][]),
        )) {
          const k = r.image_blob_key?.trim();
          if (k) blobKeys.add(k);
        }
        for (const p of Object.values(
          Object.fromEntries(photoRows.filter(Boolean) as [string, PhotoMedia][]),
        )) {
          const k = p.media_blob_key?.trim();
          if (k) blobKeys.add(k);
        }
        for (const v of Object.values(
          Object.fromEntries(videoRows.filter(Boolean) as [string, VideoMedia][]),
        )) {
          const k = v.media_blob_key?.trim();
          if (k) blobKeys.add(k);
        }
        for (const w of Object.values(
          Object.fromEntries(wxRows.filter(Boolean) as [string, WeatherAtLocationMedia][]),
        )) {
          const k = w.current_icon_blob_key?.trim();
          if (k) blobKeys.add(k);
        }

        const urlMap: Record<string, string> = {};
        await Promise.all(
          [...blobKeys].map(async (key) => {
            const url = await fetchBlobObjectUrl(display, key);
            if (cancelled) return;
            if (url) {
              objectUrls.push(url);
              urlMap[key] = url;
            }
          }),
        );
        if (cancelled) return;
        setBlobUrls(urlMap);
      } catch (e) {
        if (!cancelled) {
          setErr(e instanceof ApiError ? `${e.status}: ${e.message}` : String(e));
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
      for (const u of objectUrls) URL.revokeObjectURL(u);
    };
  }, [display, model, open]);

  if (!model) return null;

  const primaryLabel = model.screenType ?? (model.summaries[0]?.type ?? 'slide');

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth scroll="paper">
      <DialogTitle>
        Slide {slideIndex + 1} of {slideCount} · {primaryLabel}
      </DialogTitle>
      <DialogContent dividers>
        <Stack spacing={2}>
          <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
            <Chip size="small" label={primaryLabel} color="primary" variant="outlined" />
            <Chip size="small" label={`Dwell ${model.dwellLabel}`} />
          </Stack>
          <Typography variant="caption" color="text.secondary">
            Screen id: {model.screenId}
          </Typography>
          {err && <Alert severity="warning">{err}</Alert>}
          {loading && <Typography color="text.secondary">Loading details…</Typography>}

          {model.summaries.map((s) => (
            <Paper key={`${s.slot}-${s.type}`} variant="outlined" sx={{ p: 2 }}>
              <Stack spacing={1}>
                <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
                  <Chip size="small" label={s.type} />
                  <Typography variant="subtitle2" color="text.secondary">
                    {s.slot}
                  </Typography>
                </Stack>
                <Typography variant="body1" fontWeight={600}>
                  {s.headline}
                </Typography>
                {s.sub && (
                  <Typography variant="body2" color="text.secondary">
                    {s.sub}
                  </Typography>
                )}
                <WidgetDetailBlock
                  type={s.type}
                  slot={s.slot}
                  model={model}
                  rssById={rssById}
                  photoById={photoById}
                  videoById={videoById}
                  jokeById={jokeById}
                  triviaById={triviaById}
                  weatherById={weatherById}
                  blobUrls={blobUrls}
                />
              </Stack>
            </Paper>
          ))}

          <Divider />
          <Button size="small" onClick={() => setRawOpen((v) => !v)}>
            {rawOpen ? 'Hide' : 'Show'} raw layout JSON
          </Button>
          <Collapse in={rawOpen}>
            <Box
              component="pre"
              sx={{
                m: 0,
                p: 1,
                bgcolor: 'action.hover',
                borderRadius: 1,
                fontSize: 12,
                overflow: 'auto',
                maxHeight: 280,
              }}
            >
              {model.layoutJsonRaw}
            </Box>
          </Collapse>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onPrevSlide} disabled={slideIndex <= 0}>
          Previous slide
        </Button>
        <Button onClick={onNextSlide} disabled={slideIndex >= slideCount - 1}>
          Next slide
        </Button>
        <Box sx={{ flex: 1 }} />
        <Button onClick={onClose}>Close</Button>
      </DialogActions>
    </Dialog>
  );
}

function WidgetDetailBlock({
  type,
  slot,
  model,
  rssById,
  photoById,
  videoById,
  jokeById,
  triviaById,
  weatherById,
  blobUrls,
}: {
  type: string;
  slot: string;
  model: SlideCardModel;
  rssById: Record<string, RssArticleMedia>;
  photoById: Record<string, PhotoMedia>;
  videoById: Record<string, VideoMedia>;
  jokeById: Record<string, JokeMedia>;
  triviaById: Record<string, TriviaMedia>;
  weatherById: Record<string, WeatherAtLocationMedia>;
  blobUrls: Record<string, string>;
}) {
  const choiceKey = `${slot}_${type}`;

  if (type === 'rss_article') {
    const id = model.randomChoices[choiceKey];
    const row = id ? rssById[id] : undefined;
    if (!row) return <Typography variant="body2">Curated article id not resolved yet.</Typography>;
    const src = row.image_blob_key ? blobUrls[row.image_blob_key] : undefined;
    return (
      <Stack spacing={1}>
        <Typography variant="body2">{row.summary}</Typography>
        <Link href={row.link} target="_blank" rel="noreferrer">
          Open article
        </Link>
        {src && (
          <Box
            component="img"
            src={src}
            alt={row.title}
            sx={{ maxWidth: '100%', borderRadius: 1, maxHeight: 360, objectFit: 'contain' }}
          />
        )}
      </Stack>
    );
  }

  if (type === 'rss_article_columns' || type === 'rss_article_stack') {
    const slots: { label: string; id: string }[] = [];
    for (let i = 0; i < 12; i++) {
      const id = model.randomChoices[`${choiceKey}_${i}`];
      if (id) slots.push({ label: `Slot ${i + 1}`, id });
    }
    if (slots.length === 0) {
      const primary = model.randomChoices[choiceKey];
      if (primary) slots.push({ label: 'Primary', id: primary });
    }
    return (
      <Stack spacing={2}>
        {slots.map((s) => {
          const row = rssById[s.id];
          const src = row?.image_blob_key ? blobUrls[row.image_blob_key] : undefined;
          return (
            <Stack key={s.id} spacing={0.5}>
              <Typography variant="caption" color="text.secondary">
                {s.label}
              </Typography>
              {row ? (
                <>
                  <Typography variant="body2" fontWeight={600}>
                    {row.title}
                  </Typography>
                  <Typography variant="body2">{row.summary}</Typography>
                  <Link href={row.link} target="_blank" rel="noreferrer">
                    Open article
                  </Link>
                  {src && (
                    <Box
                      component="img"
                      src={src}
                      alt={row.title}
                      sx={{ maxWidth: '100%', borderRadius: 1, maxHeight: 240, objectFit: 'contain' }}
                    />
                  )}
                </>
              ) : (
                <Typography variant="body2" color="text.secondary">
                  No metadata for {s.id}
                </Typography>
              )}
            </Stack>
          );
        })}
      </Stack>
    );
  }

  if (type === 'pexels_photo') {
    const id = model.randomChoices[choiceKey];
    const row = id ? photoById[id] : undefined;
    if (!row) return null;
    const src = row.media_blob_key ? blobUrls[row.media_blob_key] : undefined;
    return (
      <Stack spacing={1}>
        <Typography variant="body2" color="text.secondary">
          {row.photographer_name}
        </Typography>
        {row.pexels_page_url && (
          <Link href={row.pexels_page_url} target="_blank" rel="noreferrer">
            View on Pexels
          </Link>
        )}
        {src && (
          <Box
            component="img"
            src={src}
            alt={row.alt_text || 'Photo'}
            sx={{ maxWidth: '100%', borderRadius: 1, maxHeight: 360, objectFit: 'contain' }}
          />
        )}
      </Stack>
    );
  }

  if (type === 'pexels_photo_collage') {
    const ids: string[] = [];
    for (let i = 0; i < 12; i++) {
      const pid = model.randomChoices[`${choiceKey}_${i}`];
      if (pid) ids.push(pid);
    }
    return (
      <Stack direction="row" flexWrap="wrap" gap={1}>
        {ids.map((id) => {
          const row = photoById[id];
          const src = row?.media_blob_key ? blobUrls[row.media_blob_key] : undefined;
          return (
            <Card key={id} variant="outlined" sx={{ width: 160 }}>
              {src ? (
                <Box
                  component="img"
                  src={src}
                  alt={row?.alt_text || id}
                  sx={{ width: '100%', height: 120, objectFit: 'cover', display: 'block' }}
                />
              ) : (
                <Box sx={{ p: 1, height: 120, bgcolor: 'action.hover' }}>
                  <Typography variant="caption">{id}</Typography>
                </Box>
              )}
            </Card>
          );
        })}
      </Stack>
    );
  }

  if (type === 'pexels_video') {
    const id = model.randomChoices[choiceKey];
    const row = id ? videoById[id] : undefined;
    if (!row) return null;
    const src = row.media_blob_key ? blobUrls[row.media_blob_key] : undefined;
    return (
      <Stack spacing={1}>
        <Typography variant="body2" color="text.secondary">
          {row.photographer_name}
          {row.duration_seconds != null ? ` · ${row.duration_seconds}s` : ''}
        </Typography>
        {row.pexels_page_url && (
          <Link href={row.pexels_page_url} target="_blank" rel="noreferrer">
            View on Pexels
          </Link>
        )}
        {src && (
          <Box component="video" src={src} controls sx={{ width: '100%', maxHeight: 360, borderRadius: 1 }} />
        )}
      </Stack>
    );
  }

  if (type === 'joke') {
    const id = model.randomChoices[choiceKey];
    const row = id ? jokeById[id] : undefined;
    if (!row) return null;
    return (
      <Stack spacing={0.5}>
        <Typography variant="body2">{row.setup}</Typography>
        <Typography variant="body2" fontStyle="italic">
          {row.punchline}
        </Typography>
      </Stack>
    );
  }

  if (type === 'trivia') {
    const id = model.randomChoices[choiceKey];
    const row = id ? triviaById[id] : undefined;
    if (!row) return null;
    return (
      <Stack spacing={0.5}>
        <Typography variant="body2" fontWeight={600}>
          {row.question}
        </Typography>
        <Typography variant="body2">A) {row.option_a}</Typography>
        <Typography variant="body2">B) {row.option_b}</Typography>
        <Typography variant="body2">C) {row.option_c}</Typography>
        <Typography variant="body2">D) {row.option_d}</Typography>
        <Typography variant="caption" color="text.secondary">
          Answer: {row.correct_option}
        </Typography>
      </Stack>
    );
  }

  if (type === 'weather') {
    const w = model.widgets.find((x) => x.slot === slot && x.type === 'weather');
    const locId = w ? cfgStr(w.config, 'locationId', 'location_id').trim() : '';
    const wx = locId ? weatherById[locId] : undefined;
    if (!wx) {
      return (
        <Typography variant="body2" color="text.secondary">
          {locId ? `No live weather loaded for “${locId}”.` : 'No location selected in layout.'}
        </Typography>
      );
    }
    const t =
      wx.current_temp_c != null && Number.isFinite(wx.current_temp_c)
        ? `${wx.current_temp_c.toFixed(0)}°C`
        : '';
    const d = (wx.current_description ?? '').trim();
    const line = [wx.location_name, t, d].filter(Boolean).join(' · ');
    const ik = wx.current_icon_blob_key?.trim();
    const iconSrc = ik ? blobUrls[ik] : undefined;
    return (
      <Stack direction="row" spacing={2} alignItems="center">
        {iconSrc && (
          <Box
            component="img"
            src={iconSrc}
            alt=""
            sx={{ width: 72, height: 72, objectFit: 'contain' }}
          />
        )}
        <Typography variant="body1" fontWeight={600}>
          {line}
        </Typography>
      </Stack>
    );
  }

  return null;
}

function TickerItemDetailDialog({
  open,
  onClose,
  atMs,
  items,
  index,
  onPrev,
  onNext,
}: {
  open: boolean;
  onClose: () => void;
  atMs: number;
  items: Record<string, unknown>[];
  index: number;
  onPrev: () => void;
  onNext: () => void;
}) {
  const item = items[index] ?? {};
  const kind = String(item['kind'] ?? '');
  const body = String(item['body'] ?? '');
  const sourceId = item['source_id'] == null ? '' : String(item['source_id']);
  const rss = item['rss'] && typeof item['rss'] === 'object' ? (item['rss'] as Record<string, unknown>) : null;

  const total = items.length;

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>
        Ticker item {index + 1} of {total} · {programTimestamp(atMs)}
      </DialogTitle>
      <DialogContent dividers>
        <Stack spacing={2}>
          <Chip size="small" label={kind} color="secondary" variant="outlined" />
          {sourceId && (
            <Typography variant="body2" color="text.secondary">
              Source id: {sourceId}
            </Typography>
          )}
          {rss ? (
            <Stack spacing={1}>
              {(rss['show_source'] === true || rss['show_source'] === 'true') &&
              typeof rss['source_title'] === 'string' &&
              rss['source_title'].trim() !== '' ? (
                <Typography variant="overline" color="text.secondary">
                  [{rss['source_title']}]
                </Typography>
              ) : null}
              {typeof rss['article_title'] === 'string' && rss['article_title'].trim() !== '' ? (
                <Typography variant="h6">{rss['article_title']}</Typography>
              ) : null}
              {typeof rss['summary'] === 'string' && rss['summary'].trim() !== '' ? (
                <Typography variant="body2">{rss['summary']}</Typography>
              ) : null}
              <Divider />
              <Typography variant="body2" color="text.secondary">
                Plain body (dedupe key)
              </Typography>
              <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
                {body}
              </Typography>
            </Stack>
          ) : (
            <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
              {body}
            </Typography>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onPrev} disabled={index <= 0}>
          Previous item
        </Button>
        <Button onClick={onNext} disabled={index >= total - 1}>
          Next item
        </Button>
        <Box sx={{ flex: 1 }} />
        <Button onClick={onClose}>Close</Button>
      </DialogActions>
    </Dialog>
  );
}

export function ProgramsPage() {
  const { active } = useDisplay();
  const { hasPermission } = useAuth();
  const [screen, setScreen] = useState<Record<string, unknown>[]>([]);
  const [ticker, setTicker] = useState<Record<string, unknown>[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [navSnack, setNavSnack] = useState<string | null>(null);
  const [slideDetailLoc, setSlideDetailLoc] = useState<{ pi: number; si: number } | null>(null);
  const [tickerDetailLoc, setTickerDetailLoc] = useState<{ pi: number; ii: number } | null>(null);

  const lastScreenJson = useRef<string | null>(null);
  const lastTickerJson = useRef<string | null>(null);

  useEffect(() => {
    lastScreenJson.current = null;
    lastTickerJson.current = null;
  }, [active?.id]);

  const load = useCallback(async () => {
    if (!active) return;
    try {
      const [s, t] = await Promise.all([
        apiJson<Items<Record<string, unknown>>>(active, '/v1/telemetry/programs'),
        apiJson<Items<Record<string, unknown>>>(active, '/v1/telemetry/ticker-programs'),
      ]);
      const nextScreen = s.items ?? [];
      const nextTicker = t.items ?? [];
      const screenJson = JSON.stringify(nextScreen);
      const tickerJson = JSON.stringify(nextTicker);
      if (lastScreenJson.current !== screenJson) {
        lastScreenJson.current = screenJson;
        setScreen(nextScreen);
      }
      if (lastTickerJson.current !== tickerJson) {
        lastTickerJson.current = tickerJson;
        setTicker(nextTicker);
      }
      setError((prev) => (prev != null ? null : prev));
    } catch (e) {
      const msg = e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
      setError((prev) => (prev === msg ? prev : msg));
    }
  }, [active]);

  useEffect(() => {
    void load();
    const id = window.setInterval(() => void load(), 5000);
    return () => window.clearInterval(id);
  }, [load]);

  const screenProgramsDesc = useMemo(
    () =>
      [...screen].sort((a, b) => {
        const ta = typeof a.at_ms === 'number' ? a.at_ms : Number(a.at_ms) || 0;
        const tb = typeof b.at_ms === 'number' ? b.at_ms : Number(b.at_ms) || 0;
        return tb - ta;
      }),
    [screen],
  );

  const tickerProgramsDesc = useMemo(
    () =>
      [...ticker].sort((a, b) => {
        const ta = typeof a.at_ms === 'number' ? a.at_ms : Number(a.at_ms) || 0;
        const tb = typeof b.at_ms === 'number' ? b.at_ms : Number(b.at_ms) || 0;
        return tb - ta;
      }),
    [ticker],
  );

  const slideDetailSlides = useMemo(() => {
    if (slideDetailLoc == null) return [] as Record<string, unknown>[];
    const row = screenProgramsDesc[slideDetailLoc.pi];
    if (!row) return [];
    return asRecordArray(row['slides']);
  }, [slideDetailLoc, screenProgramsDesc]);

  const slideDetailModel = useMemo((): SlideCardModel | null => {
    if (slideDetailLoc == null || slideDetailSlides.length === 0) return null;
    const slide = slideDetailSlides[slideDetailLoc.si];
    if (!slide) return null;
    return buildSlideCardModel(slide, slideDetailLoc.si);
  }, [slideDetailLoc, slideDetailSlides]);

  const tickerDetailRow = useMemo(() => {
    if (tickerDetailLoc == null) return null;
    return tickerProgramsDesc[tickerDetailLoc.pi] ?? null;
  }, [tickerDetailLoc, tickerProgramsDesc]);

  const tickerDetailItems = useMemo(() => {
    if (!tickerDetailRow) return [] as Record<string, unknown>[];
    return asRecordArray(tickerDetailRow['items']);
  }, [tickerDetailRow]);

  const postNav = useCallback(
    async (surface: 'screen' | 'ticker', direction: 'back' | 'forward') => {
      if (!active) return;
      try {
        await apiFetch(active, '/v1/display/navigation', {
          method: 'POST',
          body: JSON.stringify({ surface, direction }),
        });
      } catch (e) {
        const msg = e instanceof ApiError ? `${e.status}: ${e.message}` : String(e);
        setNavSnack(msg);
      }
    },
    [active],
  );

  if (!active) {
    return <NoDisplayPlaceholder />;
  }

  return (
    <Stack spacing={3}>
      <Snackbar
        open={navSnack != null}
        autoHideDuration={6000}
        onClose={() => setNavSnack(null)}
        message={navSnack ?? ''}
      />
      <Typography variant="h5" fontWeight={600}>
        Programs
      </Typography>
      {error && <Alert severity="error">{error}</Alert>}

      {hasPermission('navigation.control') && (
        <Paper variant="outlined" sx={{ p: 1.5 }}>
          <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
            <Typography variant="subtitle2" fontWeight={600} sx={{ mr: 0.5 }}>
              Display remote
            </Typography>
            <Typography variant="caption" color="text.secondary" sx={{ flexBasis: '100%' }}>
              Same as controller arrow hotkeys: ← → for slides, ↑ ↓ for ticker.
            </Typography>
            <Tooltip title="Previous slide (←)">
              <IconButton
                size="small"
                onClick={() => void postNav('screen', 'back')}
                aria-label="Previous slide"
              >
                <KeyboardArrowLeftIcon />
              </IconButton>
            </Tooltip>
            <Tooltip title="Next slide (→)">
              <IconButton
                size="small"
                onClick={() => void postNav('screen', 'forward')}
                aria-label="Next slide"
              >
                <KeyboardArrowRightIcon />
              </IconButton>
            </Tooltip>
            <Tooltip title="Ticker backward (↑)">
              <IconButton
                size="small"
                onClick={() => void postNav('ticker', 'back')}
                aria-label="Ticker previous"
              >
                <KeyboardArrowUpIcon />
              </IconButton>
            </Tooltip>
            <Tooltip title="Ticker forward (↓)">
              <IconButton
                size="small"
                onClick={() => void postNav('ticker', 'forward')}
                aria-label="Ticker next"
              >
                <KeyboardArrowDownIcon />
              </IconButton>
            </Tooltip>
          </Stack>
        </Paper>
      )}

      <Typography variant="subtitle1" fontWeight={600}>
        Screen programs
      </Typography>
      <Stack spacing={2}>
        {screenProgramsDesc.map((row, pi) => {
          const slides = asRecordArray(row['slides']);
          const atMs = typeof row.at_ms === 'number' ? row.at_ms : Number(row.at_ms) || 0;
          const reason = String(row['reason'] ?? '');
          return (
            <Paper key={`${atMs}-sp-${pi}`} variant="outlined" sx={{ p: 2 }}>
              <Stack spacing={1.5}>
                <Stack
                  direction={{ xs: 'column', sm: 'row' }}
                  spacing={1}
                  justifyContent="space-between"
                  alignItems={{ xs: 'flex-start', sm: 'center' }}
                >
                  <div>
                    <Typography variant="subtitle1" fontWeight={600}>
                      Curated {new Date(atMs).toLocaleTimeString(undefined, { timeStyle: 'short' })}
                    </Typography>
                    {reason && (
                      <Typography variant="body2" color="text.secondary">
                        Reason: {reason}
                      </Typography>
                    )}
                  </div>
                  <Chip label={`${slides.length} slide${slides.length === 1 ? '' : 's'}`} size="small" />
                </Stack>
                <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1.5 }}>
                  {slides.map((slide, si) => {
                    const model = buildSlideCardModel(slide, si);
                    return (
                      <SlideProgramCard
                        key={`${model.screenId}-${si}`}
                        display={active}
                        model={model}
                        onDetails={() => setSlideDetailLoc({ pi, si })}
                      />
                    );
                  })}
                </Box>
                {slides.length === 0 && (
                  <Typography variant="body2" color="text.secondary">
                    No slides in this program snapshot.
                  </Typography>
                )}
              </Stack>
            </Paper>
          );
        })}
        {screen.length === 0 && (
          <Typography variant="body2" color="text.secondary">
            No samples yet (wait for the display to build a program).
          </Typography>
        )}
      </Stack>

      <Typography variant="subtitle1" fontWeight={600}>
        Ticker programs
      </Typography>
      <Stack spacing={2}>
        {tickerProgramsDesc.map((row, pi) => {
          const items = asRecordArray(row['items']);
          const atMs = typeof row.at_ms === 'number' ? row.at_ms : Number(row.at_ms) || 0;
          return (
            <Paper key={`${atMs}-tp-${pi}`} variant="outlined" sx={{ p: 2 }}>
              <Stack spacing={1.5}>
                <Stack
                  direction={{ xs: 'column', sm: 'row' }}
                  spacing={1}
                  justifyContent="space-between"
                  alignItems={{ xs: 'flex-start', sm: 'center' }}
                >
                  <div>
                    <Typography variant="subtitle1" fontWeight={600}>
                      Curated {new Date(atMs).toLocaleTimeString(undefined, { timeStyle: 'short' })}
                    </Typography>
                  </div>
                  <Chip label={`${items.length} tape${items.length === 1 ? '' : 's'}`} size="small" />
                </Stack>
                <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1.5 }}>
                  {items.map((it, ii) => {
                    const kind = String(it['kind'] ?? '');
                    return (
                      <TickerProgramCard
                        key={`${atMs}-ti-${ii}`}
                        index={ii}
                        item={it}
                        kind={kind}
                        onDetails={() => setTickerDetailLoc({ pi, ii })}
                      />
                    );
                  })}
                </Box>
                {items.length === 0 && (
                  <Typography variant="body2" color="text.secondary">
                    No ticker items in this snapshot.
                  </Typography>
                )}
              </Stack>
            </Paper>
          );
        })}
        {ticker.length === 0 && (
          <Typography variant="body2" color="text.secondary">
            No ticker program snapshots yet.
          </Typography>
        )}
      </Stack>

      <SlideTelemetryDetail
        display={active}
        model={slideDetailModel}
        open={slideDetailLoc != null}
        onClose={() => setSlideDetailLoc(null)}
        slideIndex={slideDetailLoc?.si ?? 0}
        slideCount={slideDetailSlides.length}
        onPrevSlide={() =>
          setSlideDetailLoc((c) => (c && c.si > 0 ? { ...c, si: c.si - 1 } : c))
        }
        onNextSlide={() =>
          setSlideDetailLoc((c) =>
            c && c.si < slideDetailSlides.length - 1 ? { ...c, si: c.si + 1 } : c,
          )
        }
      />

      <TickerItemDetailDialog
        open={tickerDetailLoc != null}
        onClose={() => setTickerDetailLoc(null)}
        atMs={
          tickerDetailRow && typeof tickerDetailRow.at_ms === 'number'
            ? tickerDetailRow.at_ms
            : Number(tickerDetailRow?.at_ms) || 0
        }
        items={tickerDetailItems}
        index={tickerDetailLoc?.ii ?? 0}
        onPrev={() =>
          setTickerDetailLoc((c) => (c && c.ii > 0 ? { ...c, ii: c.ii - 1 } : c))
        }
        onNext={() =>
          setTickerDetailLoc((c) =>
            c && c.ii < tickerDetailItems.length - 1 ? { ...c, ii: c.ii + 1 } : c,
          )
        }
      />
    </Stack>
  );
}
