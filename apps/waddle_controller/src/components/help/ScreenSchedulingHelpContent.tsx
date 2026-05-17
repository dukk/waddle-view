import { Link as RouterLink } from 'react-router-dom';
import { Link, Typography } from '@mui/material';

export function ScreenSchedulingHelpContent() {
  return (
    <>
      <Typography variant="body2" component="div">
        When the display builds a <strong>screen program</strong>, the curator fills a time budget
        (set under{' '}
        <Link component={RouterLink} to="/display-settings">
          Display settings
        </Link>{' '}
        as <strong>Program duration</strong>) by repeatedly choosing enabled screens. Each placement
        reserves up to that screen&apos;s dwell; the carousel may show the same screen more than once
        in one program if the budget allows.
      </Typography>
      <Typography variant="body2" component="div">
        <strong>Dwell seconds</strong> — How long this screen stays on screen each time it is picked
        in a program. The last slide in a program may use fewer seconds if the budget is almost full.
        A dwell of 0 excludes the screen from program curation (it will not rotate automatically).
      </Typography>
      <Typography variant="body2" component="div">
        <strong>Frequency weight</strong> — Relative pick chance versus other enabled screens.
        Effective weight is <code>weight ÷ (1 + times in recent history)</code>, so screens shown
        lately are deprioritized. Example: weight 200 is twice as likely as 100 when both are equally
        &quot;fresh.&quot; The recent-history window is <strong>History depth</strong> on Display
        settings (default 5 past placements).
      </Typography>
    </>
  );
}
