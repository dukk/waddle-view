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
        <code>news</code> (RSS), <code>quote</code>, <code>stocks</code>, and <code>custom</code>{' '}
        (marquee keys from <code>config_key_values</code>). Use <code>config_json</code> for
        fallbacks such as <code>fallbackText</code> when live data is missing.
      </Typography>
      <Typography variant="body2" component="div">
        Scroll speed is <strong>Ticker pixels per second</strong> under{' '}
        <Link component={RouterLink} to="/display-settings">
          Display settings
        </Link>
        . Disabled tapes are omitted from the marquee until enabled again.
      </Typography>
    </>
  );
}
