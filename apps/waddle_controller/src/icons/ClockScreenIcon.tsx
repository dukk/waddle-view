import { createSvgIcon } from '@mui/material/utils';

/** Clock screen (digital or analog): round face with hands. */
export const ClockScreenIcon = createSvgIcon(
  <>
    <circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" strokeWidth="1.75" />
    <path d="M12 7v5.25l3.5 2" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    <circle cx="12" cy="12" r="1.25" />
    <path d="M12 4.25v1.1M12 18.65v1.1M4.25 12h1.1M18.65 12h1.1" fill="none" stroke="currentColor" strokeWidth="1.1" strokeLinecap="round" opacity="0.55" />
  </>,
  'ClockScreen',
);
