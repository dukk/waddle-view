import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { Box, Typography, useTheme } from '@mui/material';
import { TICKER_SPEED_SAMPLE_TEXT } from '@/constants/tickerSample';

type TickerMarqueeSamplePreviewProps = {
  pixelsPerSecond: number;
  text?: string;
};

/**
 * Right-to-left marquee preview using the same speed model as the display ticker:
 * duration = segmentWidth / pixelsPerSecond, duplicated segment for seamless loop.
 */
export function TickerMarqueeSamplePreview({
  pixelsPerSecond,
  text = TICKER_SPEED_SAMPLE_TEXT,
}: TickerMarqueeSamplePreviewProps) {
  const theme = useTheme();
  const trackRef = useRef<HTMLDivElement>(null);
  const segmentRef = useRef<HTMLSpanElement>(null);
  const [segmentWidth, setSegmentWidth] = useState(0);

  useLayoutEffect(() => {
    const el = segmentRef.current;
    if (!el) {
      return;
    }
    const measure = () => {
      setSegmentWidth(el.getBoundingClientRect().width);
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, [text]);

  useEffect(() => {
    const track = trackRef.current;
    if (!track || segmentWidth <= 0 || pixelsPerSecond <= 0) {
      return;
    }
    const durationMs = Math.max(1, (segmentWidth / pixelsPerSecond) * 1000);
    const anim = track.animate(
      [
        { transform: 'translateX(0px)' },
        { transform: `translateX(-${segmentWidth}px)` },
      ],
      {
        duration: durationMs,
        iterations: Infinity,
        easing: 'linear',
      },
    );
    return () => anim.cancel();
  }, [segmentWidth, pixelsPerSecond]);

  const labelStyle = {
    whiteSpace: 'nowrap' as const,
    px: 1.5,
    fontWeight: 600,
    fontSize: theme.typography.titleLarge?.fontSize ?? '1.25rem',
    lineHeight: 1.2,
    color: theme.palette.text.primary,
  };

  return (
    <Box
      role="region"
      aria-label="Ticker speed sample"
      sx={{
        mt: 1,
        height: 56,
        borderRadius: 1,
        overflow: 'hidden',
        border: 1,
        borderColor: 'divider',
        bgcolor:
          theme.palette.mode === 'dark'
            ? 'rgba(255,255,255,0.06)'
            : 'rgba(0,0,0,0.04)',
      }}
    >
      <Box sx={{ height: '100%', overflow: 'hidden', display: 'flex', alignItems: 'center' }}>
        <Box ref={trackRef} sx={{ display: 'flex', width: 'max-content', willChange: 'transform' }}>
          <Typography component="span" ref={segmentRef} sx={labelStyle}>
            {text}
          </Typography>
          <Typography component="span" aria-hidden sx={labelStyle}>
            {text}
          </Typography>
        </Box>
      </Box>
    </Box>
  );
}
