import { createSvgIcon } from '@mui/material/utils';

/** Pexels / random photo screen: landscape frame with sun. */
export const PhotoScreenIcon = createSvgIcon(
  <>
    <path d="M5 6.5h14a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2z" />
    <circle cx="9" cy="10" r="1.35" />
    <path d="M5 15.5 9.25 11.5 12 14l2.75-2.5L19 17.5" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
  </>,
  'PhotoScreen',
);
