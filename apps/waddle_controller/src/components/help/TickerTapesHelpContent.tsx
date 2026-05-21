import { Link as RouterLink } from 'react-router-dom';
import { Link, Typography } from '@mui/material';

export function TickerTapesHelpContent() {
  return (
    <>
      <Typography variant="body2" component="div">
        Enabled ticker tapes are combined into the bottom marquee. Tapes are processed in ascending{' '}
        <strong>sort order</strong> (lower numbers first), then by id when tied.
      </Typography>
      <Typography variant="body2" component="div">
        <strong>Frequency weight</strong> — How many times each tape&apos;s item bundle is repeated
        when the curator builds the marquee list. For example, weight 3 adds every line from that
        tape three times before moving on (identical bodies are still deduplicated). Weight 0 skips
        the tape. Compare weights across tapes: a tape at 200 contributes twice as many repeats as
        one at 100.
      </Typography>
      <Typography variant="body2" component="div">
        <strong>Ticker types</strong> — <code>time</code> (clock), <code>weather</code>,{' '}
        <code>news</code> (RSS), <code>stocks</code>, <code>static_text</code> (fixed{' '}
        <code>text</code> in <code>config_json</code>), and <code>plugin</code>. Weather and news
        show lines only when live/RSS data exists; plugins may use <code>fallbackText</code> when
        they return no lines.
      </Typography>
      <Typography variant="body2" component="div">
        Default <strong>ticker program duration</strong> (RSS scroll budget) and{' '}
        <strong>pixels per second</strong> are under{' '}
        <Link component={RouterLink} to="/display-settings">
          Display settings
        </Link>
        ; curators can override when active. Disabled tapes are omitted from the marquee until
        enabled again.
      </Typography>
    </>
  );
}
