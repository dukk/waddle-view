import { createSvgIcon } from '@mui/material/utils';

/** Live playout queue: slide program rotations and ticker items on the display. */
export const ProgramsPlayoutIcon = createSvgIcon(
  <>
    <path d="M3 4h18v16H3V4zm2 2v8.75h14V6H5zm0 10.75h14v3.25H5v-3.25z" />
    <path d="M6 7h10.5v2.25H6z" />
    <path d="M16.75 7.85h1.35v1.45h-1.35z" />
    <path d="M6 10.5h7.25v2H6zm0 3.25h8.75v2H6z" />
    <path d="M6.5 17.85h7v.85H6.5z" />
    <path d="M14.75 17.85H18v.85h-3.25z" opacity="0.55" />
  </>,
  'ProgramsPlayout',
);
