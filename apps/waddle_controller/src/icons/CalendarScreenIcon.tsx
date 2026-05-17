import { createSvgIcon } from '@mui/material/utils';

/** Calendar month screen: wall calendar with a highlighted day. */
export const CalendarScreenIcon = createSvgIcon(
  <>
    <path d="M6 5.5h12a2 2 0 0 1 2 2v11.5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7.5a2 2 0 0 1 2-2z" />
    <path d="M8 3.75v3.25M16 3.75v3.25M5 9.75h14" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    <path d="M8.25 12.5h2.25v2.25H8.25z" opacity="0.85" />
    <path d="M11.75 12.5h2v2.25h-2zm3.25 0H17v2.25h-2zm-6.5 3.5h2v2.25h-2zm3.25 0h2v2.25h-2zm3.25 0H17v2.25h-2z" opacity="0.45" />
  </>,
  'CalendarScreen',
);
