import { createSvgIcon } from '@mui/material/utils';

/** Stock quotes screen: upward trend with bars. */
export const StockScreenIcon = createSvgIcon(
  <>
    <path d="M4 18.5h16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
    <path d="M6.5 15.25V18.5M10 12.5V18.5M13.5 14V18.5M17 9.25V18.5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    <path d="M6.25 11.75 11.25 7.25l3 2.75 5.25-6.25" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M16.75 3.75 19.5 6.5 19.5 3.75z" />
  </>,
  'StockScreen',
);
