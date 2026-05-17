import { createSvgIcon } from '@mui/material/utils';

/** Data health screen: heartbeat pulse on a panel. */
export const DataHealthScreenIcon = createSvgIcon(
  <>
    <path d="M5 6.5h14a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2z" />
    <path d="M6.75 12.75h2.1l1.35-2.7 1.8 5.4 1.35-2.7h2.95" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M7.25 17.75h9.5" fill="none" stroke="currentColor" strokeWidth="1.25" strokeLinecap="round" opacity="0.45" />
  </>,
  'DataHealthScreen',
);
