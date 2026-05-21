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
        <strong>Effects</strong> are full-screen or motion layers (shape rain, confetti, matrix rain,
        edge glow, bouncing message, falling images, balloons). They do not use viewport position —
        no placement sliders.
      </Typography>
      <Typography variant="body2" sx={{ mt: 1 }}>
        <strong>Widgets</strong> are positioned on the display (static image, photo slideshow,
        digital/analog clocks, calendars, stock quote, QR code). Use the position and scale sliders to
        anchor them on the viewport (top-left anchor).
      </Typography>
      <Typography variant="body2" sx={{ mt: 1 }}>
        <strong>When it runs</strong> — Scheduling is not on this page. On{' '}
        <strong>Curators</strong>, pick overlays on the Overlay tab and set calendar or time rules on
        the Schedule tab. The display shows an overlay only when an active curator configuration
        includes it. A global overlay toggle in SQLite can still suppress all overlays.
      </Typography>
      <Typography variant="body2" sx={{ mt: 1 }}>
        Edit configuration here; delete removes the row from SQLite. Overlay type cannot be changed
        after create — delete and add a new overlay to switch between an effect and a widget.
      </Typography>
    </>
  );
}
