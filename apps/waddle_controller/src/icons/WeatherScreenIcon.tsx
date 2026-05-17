import { createSvgIcon } from '@mui/material/utils';

/** Weather screen: sun peeking from behind a cloud. */
export const WeatherScreenIcon = createSvgIcon(
  <>
    <path d="M6.5 18.25h10.75a3.75 3.75 0 0 0 .35-7.49 5.25 5.25 0 0 0-10.2-1.51A4 4 0 0 0 6.5 18.25z" />
    <circle cx="16.75" cy="8.25" r="2.75" />
    <path d="M16.75 4.5v1.35M20.5 8.25h-1.35M16.75 12v-1.35M13 8.25h1.35M19.45 5.55l-.95.95M19.45 10.95l-.95-.95M14.05 10.95l.95-.95M14.05 5.55l.95.95" fill="none" stroke="currentColor" strokeWidth="1.1" strokeLinecap="round" />
  </>,
  'WeatherScreen',
);
