import { createSvgIcon } from '@mui/material/utils';

/** Local API screen: terminal window with prompt. */
export const LocalApiScreenIcon = createSvgIcon(
  <>
    <path d="M4.5 6.5h15a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-15a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2z" />
    <path d="M4.5 9.5h15" fill="none" stroke="currentColor" strokeWidth="1.35" />
    <circle cx="7" cy="8" r=".65" />
    <circle cx="9.1" cy="8" r=".65" opacity="0.65" />
    <circle cx="11.2" cy="8" r=".65" opacity="0.4" />
    <path d="m7.25 13.25 2.25 2-2.25 2" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M11.5 17.25h5.25" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
  </>,
  'LocalApiScreen',
);
