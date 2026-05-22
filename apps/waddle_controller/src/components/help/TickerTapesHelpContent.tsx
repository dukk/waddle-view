import { Link as RouterLink } from 'react-router-dom';
import { Link, Typography } from '@mui/material';
import {
  DISPLAY_SETTINGS_TAB_GENERAL,
  DISPLAY_SETTINGS_TAB_PROGRAMS,
  displaySettingsPath,
} from '@/constants/displaySettingsTabs';

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
        <strong>Ticker types</strong> — <code>time</code> (live clock with format presets and optional
        zone/prefix), <code>weather</code> (optional location and °F/°C override),{' '}
        <code>news</code> (optional RSS category filter and feed prefix),{' '}
        <code>stocks</code> (optional symbol list; colored up/down), <code>quote</code>,{' '}
        <code>static_text</code>, and <code>plugin</code>. Global weather temperature unit is under{' '}
        <Link component={RouterLink} to={displaySettingsPath(DISPLAY_SETTINGS_TAB_GENERAL)}>
          Display settings → General
        </Link>
        .
      </Typography>
      <Typography variant="body2" component="div">
        Default <strong>ticker program duration</strong> (RSS scroll budget) and{' '}
        <strong>pixels per second</strong> are under{' '}
        <Link component={RouterLink} to={displaySettingsPath(DISPLAY_SETTINGS_TAB_PROGRAMS)}>
          Display settings → Programs
        </Link>
        ; curators can override when active. Disabled tapes are omitted from the marquee until
        enabled again.
      </Typography>
    </>
  );
}
