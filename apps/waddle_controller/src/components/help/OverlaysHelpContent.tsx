import { Typography } from '@mui/material';

export function OverlaysHelpContent() {
  return (
    <>
      <Typography variant="body2">
        Each overlay is a reusable definition: a <strong>name</strong>, <strong>type</strong>, and{' '}
        <code>config_json</code> tuned with the schema-driven form (switches, sliders, image uploads
        for falling images).
      </Typography>
      <Typography variant="body2" sx={{ mt: 1 }}>
        <strong>When it runs</strong> — Scheduling is not on this page. On{' '}
        <strong>Curators</strong>, pick overlays on the Overlay tab and set calendar or time rules on
        the Schedule tab. The display shows an overlay only when an active curator configuration
        includes it. A global overlay toggle in SQLite can still suppress all overlays.
      </Typography>
      <Typography variant="body2" sx={{ mt: 1 }}>
        <strong>Overlay type</strong> selects the renderer (hearts rain, birthday confetti, bouncing
        message, falling images). Edit configuration here; delete removes the row from SQLite.
      </Typography>
    </>
  );
}
