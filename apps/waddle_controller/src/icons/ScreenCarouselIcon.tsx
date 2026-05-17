import { createSvgIcon } from '@mui/material/utils';

/** Full-screen slide carousel on the display (stacked slides, arrows, pager dots). */
export const ScreenCarouselIcon = createSvgIcon(
  <>
    <path d="M4 7.5h11v10H4V7.5z" />
    <path d="M7.5 5h12.5v10H7.5V5z" />
    <path d="M9.25 9.25 7.5 11l1.75 1.75V9.25zm6 0V13l1.75-1.75L15.25 9.25z" />
    <path d="M10.25 18.75h1.5v1.5h-1.5zm2.75 0h1.5v1.5h-1.5zm2.75 0h1.5v1.5h-1.5z" />
  </>,
  'ScreenCarousel',
);
