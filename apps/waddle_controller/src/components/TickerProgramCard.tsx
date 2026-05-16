import { useMemo } from 'react';
import {
  Box,
  Button,
  Card,
  CardActions,
  CardContent,
  Chip,
  Divider,
  Stack,
  Typography,
} from '@mui/material';

type Props = {
  index: number;
  item: Record<string, unknown>;
  kind: string;
  onDetails: () => void;
};

export function TickerProgramCard({ index, item, kind, onDetails }: Props) {
  const rss = item['rss'] && typeof item['rss'] === 'object' ? (item['rss'] as Record<string, unknown>) : null;
  const articleTitle =
    rss && typeof rss['article_title'] === 'string' ? rss['article_title'].trim() : '';
  const summary = rss && typeof rss['summary'] === 'string' ? rss['summary'].trim() : '';
  const sourceTitle = rss && typeof rss['source_title'] === 'string' ? rss['source_title'].trim() : '';
  const body = String(item['body'] ?? '');

  const sourceIdRaw = item['source_id'];
  const caption =
    sourceIdRaw != null && String(sourceIdRaw).trim() !== ''
      ? `Source: ${String(sourceIdRaw).trim()}`
      : 'Ticker item';

  const headline = useMemo(() => {
    if (kind === 'news' && articleTitle) return articleTitle;
    if (kind === 'weather') return body;
    return body.length > 160 ? `${body.slice(0, 157)}…` : body;
  }, [kind, articleTitle, body]);

  const sub = useMemo(() => {
    if (kind === 'news' && summary) return summary;
    if (kind === 'news' && sourceTitle) return sourceTitle;
    return '';
  }, [kind, summary, sourceTitle]);

  const extraBody = kind !== 'news' && !sub && headline !== body ? body : null;

  const kindLabel = kind || 'item';

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
            <Chip size="small" label={`#${index + 1}`} />
            <Chip size="small" label={kindLabel} color="primary" variant="outlined" />
          </Stack>
          <Typography variant="caption" color="text.secondary">
            {caption}
          </Typography>
          <Divider />
          <Box
            sx={{
              position: 'relative',
              borderRadius: 1,
              overflow: 'hidden',
              bgcolor: 'action.hover',
              minHeight: 132,
              display: 'flex',
              alignItems: 'flex-start',
              p: 1.5,
            }}
          >
            <Stack spacing={0.5} sx={{ width: '100%' }}>
              <Typography variant="subtitle2" fontWeight={600} sx={{ whiteSpace: 'pre-wrap' }}>
                {headline}
              </Typography>
              {sub ? (
                <Typography variant="body2" color="text.secondary" sx={{ whiteSpace: 'pre-wrap' }}>
                  {sub}
                </Typography>
              ) : null}
              {extraBody ? (
                <Typography variant="body2" color="text.secondary" sx={{ whiteSpace: 'pre-wrap' }}>
                  {extraBody}
                </Typography>
              ) : null}
            </Stack>
          </Box>
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
