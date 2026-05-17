import { createSvgIcon } from '@mui/material/utils';

/** Joke screen: speech bubble with a smile. */
export const JokeScreenIcon = createSvgIcon(
  <>
    <path d="M5 4h14a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H9.5L5 19.5V16H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z" />
    <circle cx="9" cy="10" r="1.1" />
    <circle cx="15" cy="10" r="1.1" />
    <path d="M9.25 13.25c.9.75 2.1.75 3 0" fill="none" stroke="currentColor" strokeWidth="1.25" strokeLinecap="round" />
  </>,
  'JokeScreen',
);
