import { createSvgIcon } from '@mui/material/utils';

/** Scrolling ticker band along the bottom of the display. */
export const TickerTapeIcon = createSvgIcon(
  <>
    <path d="M3 4h18v16H3V4zm2 2v9h14V6H5zm0 11h14v3H5v-3z" />
    <path d="M6.5 17.15h7.25v.85H6.5zm0 1.65h5.25v.85H6.5z" />
    <path d="M14.75 17.15H18v.85h-3.25zm0 1.65H16.5v.85h-1.75z" />
    <path d="M16.85 17.55 18.6 18.4l-1.75.85zm0 2.05.85-2.35 1.75 2.35z" />
  </>,
  'TickerTape',
);
