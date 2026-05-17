import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Box,
  Button,
  Card,
  CardActions,
  CardContent,
  Chip,
  Divider,
  IconButton,
  Stack,
  Typography,
} from '@mui/material';
import ChevronLeftIcon from '@mui/icons-material/ChevronLeft';
import ChevronRightIcon from '@mui/icons-material/ChevronRight';
import { apiJson, ApiError, fetchBlobObjectUrl } from '@/api/client';
import type { SavedDisplay } from '@/storage/displays';
import { SlideScreenPreviewIcon } from '@/icons/slideScreenPreviewIcon';
import {
  collectSlideContentIds,
  collectWeatherLocationIds,
  slideScreenPreviewKind,
  type SlideCardModel,
} from '@/util/programTelemetry';

type RssArticleMedia = {
  id: string;
  title: string;
  summary?: string | null;
  link: string;
  image_blob_key?: string | null;
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
};

type WeatherAtLocation = {
  location_id: string;
  location_name: string;
  current_temp_c?: number | null;
  current_description?: string | null;
  current_icon_blob_key?: string | null;
};

type Props = {
  display: SavedDisplay;
  model: SlideCardModel;
  onDetails: () => void;
};

export function SlideProgramCard({ display, model, onDetails }: Props) {
  const [photoIdx, setPhotoIdx] = useState(0);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [rssById, setRssById] = useState<Record<string, RssArticleMedia>>({});
  const [photoById, setPhotoById] = useState<Record<string, PhotoMedia>>({});
  const [videoById, setVideoById] = useState<Record<string, VideoMedia>>({});
  const [jokeById, setJokeById] = useState<Record<string, JokeMedia>>({});
  const [triviaById, setTriviaById] = useState<Record<string, TriviaMedia>>({});
  const [weatherByLoc, setWeatherByLoc] = useState<Record<string, WeatherAtLocation>>({});
  const [blobUrls, setBlobUrls] = useState<Record<string, string>>({});

  useEffect(() => {
    setPhotoIdx(0);
    setErr(null);
    setRssById({});
    setPhotoById({});
    setVideoById({});
    setJokeById({});
    setTriviaById({});
    setWeatherByLoc({});
    setBlobUrls({});
    const objectUrls: string[] = [];
    let cancelled = false;
    (async () => {
      setLoading(true);
      try {
        const ids = collectSlideContentIds(model);
        const weatherIds = collectWeatherLocationIds(model);
        const [rssRows, photoRows, videoRows, jokeRows, triviaRows, wxRows] = await Promise.all([
          Promise.all(
            ids.rssArticleIds.map(async (id) => {
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
            ids.photoIds.map(async (id) => {
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
            ids.videoIds.map(async (id) => {
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
            ids.jokeIds.map(async (id) => {
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
            ids.triviaIds.map(async (id) => {
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
                const row = await apiJson<WeatherAtLocation>(
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
        setWeatherByLoc(Object.fromEntries(wxRows.filter(Boolean) as [string, WeatherAtLocation][]));

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
          Object.fromEntries(wxRows.filter(Boolean) as [string, WeatherAtLocation][]),
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
  }, [display, model]);

  const { firstVideo, photoIdsOrdered, firstRss, firstJoke, firstTrivia, weatherLine, wxIconKey } =
    useMemo(() => {
      const ids = collectSlideContentIds(model);
      const wxIds = collectWeatherLocationIds(model);
      let firstVideo: VideoMedia | undefined;
      for (const id of ids.videoIds) {
        const v = videoById[id];
        if (v) {
          firstVideo = v;
          break;
        }
      }
      const firstJoke = ids.jokeIds.map((id) => jokeById[id]).find(Boolean);
      const firstTrivia = ids.triviaIds.map((id) => triviaById[id]).find(Boolean);
      let firstRssId: string | undefined;
      for (const id of ids.rssArticleIds) {
        if (rssById[id]) {
          firstRssId = id;
          break;
        }
      }
      const firstRss = firstRssId ? rssById[firstRssId] : undefined;
      const wx0 = wxIds.length ? weatherByLoc[wxIds[0]!] : undefined;
      let weatherLine: string | null = null;
      let wxIconKey: string | null = null;
      if (wx0) {
        const t =
          wx0.current_temp_c != null && Number.isFinite(wx0.current_temp_c)
            ? `${wx0.current_temp_c.toFixed(0)}°C`
            : '';
        const d = (wx0.current_description ?? '').trim();
        weatherLine = [wx0.location_name, t, d].filter(Boolean).join(' · ');
        wxIconKey = wx0.current_icon_blob_key?.trim() ?? null;
      }
      return {
        firstVideo,
        photoIdsOrdered: ids.photoIds,
        firstRssId,
        firstRss,
        firstJoke,
        firstTrivia,
        weatherLine,
        wxIconKey,
      };
    }, [model, rssById, videoById, jokeById, triviaById, weatherByLoc]);

  const photoUrls = useMemo(() => {
    const urls: string[] = [];
    for (const id of photoIdsOrdered) {
      const k = photoById[id]?.media_blob_key?.trim();
      if (k && blobUrls[k]) urls.push(blobUrls[k]!);
    }
    return urls;
  }, [photoIdsOrdered, photoById, blobUrls]);

  const videoUrl = useMemo(() => {
    if (!firstVideo?.media_blob_key) return undefined;
    return blobUrls[firstVideo.media_blob_key.trim()] ?? undefined;
  }, [firstVideo, blobUrls]);

  const rssImgUrl = useMemo(() => {
    const k = firstRss?.image_blob_key?.trim();
    if (!k) return undefined;
    return blobUrls[k];
  }, [firstRss, blobUrls]);

  const wxIconUrl = wxIconKey ? blobUrls[wxIconKey] : undefined;

  const nPhotos = photoUrls.length;
  const safeIdx = nPhotos === 0 ? 0 : ((photoIdx % nPhotos) + nPhotos) % nPhotos;

  const bumpPhoto = useCallback(
    (delta: number) => {
      if (nPhotos <= 1) return;
      setPhotoIdx((i) => {
        const m = nPhotos;
        return (((i + delta) % m) + m) % m;
      });
    },
    [nPhotos],
  );

  const typeLabel = model.screenType ?? model.summaries[0]?.type ?? 'slide';
  const previewKind = useMemo(() => slideScreenPreviewKind(model), [model]);

  const hasRasterPreview =
    Boolean(videoUrl) || nPhotos > 0 || Boolean(rssImgUrl) || Boolean(wxIconUrl);
  const showTypeIllustration = !loading && !hasRasterPreview && previewKind != null;

  const textLines: string[] = [];
  if (firstJoke?.setup) textLines.push(firstJoke.setup);
  if (weatherLine) textLines.push(weatherLine);
  if (firstRss?.title) textLines.push(firstRss.title);
  if (firstTrivia?.question) textLines.push(firstTrivia.question);
  for (const s of model.summaries) {
    if (s.type === 'static_text' && s.headline && !textLines.includes(s.headline)) {
      textLines.push(s.headline);
    }
  }
  if (textLines.length === 0) {
    for (const s of model.summaries.slice(0, 2)) {
      if (s.headline) textLines.push(s.headline);
    }
  }

  return (
    <Card
      variant="outlined"
      sx={{
        width: { xs: '100%', sm: 300 },
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <CardContent sx={{ flexGrow: 1 }}>
        <Stack spacing={1}>
          <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
            <Chip size="small" label={`#${model.index + 1}`} />
            <Chip size="small" label={typeLabel} color="primary" variant="outlined" />
          </Stack>
          <Typography variant="caption" color="text.secondary">
            Dwell {model.dwellLabel}
          </Typography>
          <Divider />
          {err && (
            <Typography variant="caption" color="error">
              {err}
            </Typography>
          )}
          <Box
            sx={{
              position: 'relative',
              borderRadius: 1,
              overflow: 'hidden',
              bgcolor: 'action.hover',
              minHeight: 132,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            {loading && (
              <Typography variant="body2" color="text.secondary">
                Loading preview…
              </Typography>
            )}
            {!loading && videoUrl && (
              <Box
                component="video"
                src={videoUrl}
                muted
                playsInline
                controls
                sx={{ width: '100%', maxHeight: 200, display: 'block' }}
              />
            )}
            {!loading && !videoUrl && nPhotos > 0 && (
              <>
                <Box
                  component="img"
                  src={photoUrls[safeIdx]}
                  alt=""
                  sx={{ width: '100%', maxHeight: 200, objectFit: 'cover', display: 'block' }}
                />
                {nPhotos > 1 && (
                  <>
                    <IconButton
                      size="small"
                      onClick={() => bumpPhoto(-1)}
                      sx={{
                        position: 'absolute',
                        left: 4,
                        top: '50%',
                        transform: 'translateY(-50%)',
                        bgcolor: 'rgba(0,0,0,0.45)',
                        color: 'common.white',
                        '&:hover': { bgcolor: 'rgba(0,0,0,0.6)' },
                      }}
                      aria-label="Previous photo"
                    >
                      <ChevronLeftIcon fontSize="small" />
                    </IconButton>
                    <IconButton
                      size="small"
                      onClick={() => bumpPhoto(1)}
                      sx={{
                        position: 'absolute',
                        right: 4,
                        top: '50%',
                        transform: 'translateY(-50%)',
                        bgcolor: 'rgba(0,0,0,0.45)',
                        color: 'common.white',
                        '&:hover': { bgcolor: 'rgba(0,0,0,0.6)' },
                      }}
                      aria-label="Next photo"
                    >
                      <ChevronRightIcon fontSize="small" />
                    </IconButton>
                    <Chip
                      size="small"
                      label={`${safeIdx + 1} / ${nPhotos}`}
                      sx={{ position: 'absolute', bottom: 6, right: 6, bgcolor: 'rgba(0,0,0,0.55)', color: 'common.white' }}
                    />
                  </>
                )}
              </>
            )}
            {!loading && !videoUrl && nPhotos === 0 && rssImgUrl && (
              <Box
                component="img"
                src={rssImgUrl}
                alt={firstRss?.title ?? ''}
                sx={{ width: '100%', maxHeight: 200, objectFit: 'cover', display: 'block' }}
              />
            )}
            {!loading && !videoUrl && nPhotos === 0 && !rssImgUrl && wxIconUrl && (
              <Stack direction="row" spacing={1} alignItems="center" sx={{ p: 1 }}>
                <Box
                  component="img"
                  src={wxIconUrl}
                  alt=""
                  sx={{ width: 56, height: 56, objectFit: 'contain' }}
                />
                <Typography variant="body2">{weatherLine}</Typography>
              </Stack>
            )}
            {showTypeIllustration && (
              <SlideScreenPreviewIcon
                kind={previewKind}
                aria-hidden
                sx={{
                  fontSize: 88,
                  color: 'primary.main',
                  opacity: 0.72,
                }}
              />
            )}
          </Box>
          <Stack spacing={0.5}>
            {textLines.slice(0, 4).map((line, i) => (
              <Typography
                key={i}
                variant="body2"
                sx={{
                  display: '-webkit-box',
                  WebkitLineClamp: 3,
                  WebkitBoxOrient: 'vertical',
                  overflow: 'hidden',
                }}
              >
                {line}
              </Typography>
            ))}
          </Stack>
        </Stack>
      </CardContent>
      <CardActions sx={{ justifyContent: 'flex-end', pt: 0 }}>
        <Button size="small" onClick={onDetails}>
          Details
        </Button>
      </CardActions>
    </Card>
  );
}
