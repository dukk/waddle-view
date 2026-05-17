import { Typography } from '@mui/material';

export function OverlaysHelpContent() {
  return (
    <>
      <Typography variant="body2" component="div">
        Each schedule is a calendar rule evaluated on the display&apos;s <strong>local date</strong>
        . When a rule matches today and the row is <strong>Enabled</strong>, the display may render
        that overlay type (for example hearts rain, birthday confetti, or bouncing message). A global
        overlay toggle in SQLite can still suppress all overlays.
      </Typography>
      <Typography variant="body2" component="div">
        <strong>When it runs</strong> — Fixed calendar ranges (<code>start_month</code> /{' '}
        <code>start_day</code>, optional end), a specific <code>year_exact</code>, repeating annually,
        or a monthly rule such as &quot;2nd Tuesday.&quot; The <strong>Matches today</strong> chip on
        a card reflects this machine&apos;s calendar when you reload the list; the display uses its
        own clock at runtime.
      </Typography>
      <Typography variant="body2" component="div">
        <strong>Overlay type</strong> selects the renderer. <strong>Messages</strong> in{' '}
        <code>config_json</code> supply phrases (for example bouncing text). Edit a schedule to
        change dates, enablement, type, and configuration; delete removes the row from SQLite.
      </Typography>
    </>
  );
}
