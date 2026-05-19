import { createSvgIcon } from '@mui/material/utils';

/** Seven-segment bit flags: a=top, b=tr, c=br, d=bottom, e=bl, f=tl, g=middle. */
const SEG_A = 1 << 0;
const SEG_B = 1 << 1;
const SEG_C = 1 << 2;
const SEG_D = 1 << 3;
const SEG_E = 1 << 4;
const SEG_F = 1 << 5;
const SEG_G = 1 << 6;

const DIGIT_MASK: Record<string, number> = {
  '9': SEG_A | SEG_B | SEG_C | SEG_D | SEG_F | SEG_G,
  '4': SEG_B | SEG_C | SEG_F | SEG_G,
  '6': SEG_A | SEG_C | SEG_D | SEG_E | SEG_F | SEG_G,
};

const DIGIT_W = 2.75;
const DIGIT_H = 4.15;
const SEG_T = 0.52;

function roundedRectPath(x: number, y: number, w: number, h: number, r: number): string {
  const rx = Math.min(r, w / 2, h / 2);
  return [
    `M${x + rx},${y}`,
    `H${x + w - rx}`,
    `Q${x + w},${y} ${x + w},${y + rx}`,
    `V${y + h - rx}`,
    `Q${x + w},${y + h} ${x + w - rx},${y + h}`,
    `H${x + rx}`,
    `Q${x},${y + h} ${x},${y + h - rx}`,
    `V${y + rx}`,
    `Q${x},${y} ${x + rx},${y}`,
    'Z',
  ].join('');
}

function circlePath(cx: number, cy: number, r: number): string {
  return `M${cx},${cy - r}A${r},${r} 0 1 1 ${cx},${cy + r}A${r},${r} 0 1 1 ${cx},${cy - r}Z`;
}

/** Rounded-bar segment paths for one digit cell (used as evenodd holes). */
function digitSegmentPaths(x: number, y: number, mask: number): string[] {
  const pad = SEG_T * 0.28;
  const horizW = DIGIT_W - pad * 2;
  const vertH = (DIGIT_H - SEG_T * 3) / 2;
  const r = SEG_T / 2;
  const paths: string[] = [];

  if (mask & SEG_A) paths.push(roundedRectPath(x + pad, y, horizW, SEG_T, r));
  if (mask & SEG_F) paths.push(roundedRectPath(x, y + SEG_T * 0.85, SEG_T, vertH, r));
  if (mask & SEG_B) paths.push(roundedRectPath(x + DIGIT_W - SEG_T, y + SEG_T * 0.85, SEG_T, vertH, r));
  if (mask & SEG_G) paths.push(roundedRectPath(x + pad, y + DIGIT_H / 2 - SEG_T / 2, horizW, SEG_T, r));
  if (mask & SEG_E) paths.push(roundedRectPath(x, y + DIGIT_H / 2 + SEG_T * 0.35, SEG_T, vertH, r));
  if (mask & SEG_C) {
    paths.push(roundedRectPath(x + DIGIT_W - SEG_T, y + DIGIT_H / 2 + SEG_T * 0.35, SEG_T, vertH, r));
  }
  if (mask & SEG_D) {
    paths.push(roundedRectPath(x + pad, y + DIGIT_H - SEG_T, horizW, SEG_T, r));
  }

  return paths;
}

function colonPaths(cx: number, cy: number): string[] {
  const gap = 0.95;
  const r = 0.34;
  return [circlePath(cx, cy - gap / 2, r), circlePath(cx, cy + gap / 2, r)];
}

/** Alarm-clock body with feet (filled via evenodd with digit holes). */
function clockSilhouettePath(): string {
  const bx = 3.5;
  const by = 6;
  const bw = 17;
  const bh = 9.75;
  const br = 2.1;
  const body = roundedRectPath(bx, by, bw, bh, br);
  const leftFoot = roundedRectPath(5.1, by + bh - 0.35, 2.1, 1.85, 0.45);
  const rightFoot = roundedRectPath(16.8, by + bh - 0.35, 2.1, 1.85, 0.45);
  return `${body} ${leftFoot} ${rightFoot}`;
}

function displayHolePaths(): string {
  const y = 8.05;
  const x9 = 7.35;
  const xColon = 10.35;
  const x4 = 11.35;
  const x6 = 14.45;

  const holes: string[] = [];
  holes.push(...digitSegmentPaths(x9, y, DIGIT_MASK['9'] ?? 0));
  holes.push(...colonPaths(xColon, y + DIGIT_H / 2));
  holes.push(...digitSegmentPaths(x4, y, DIGIT_MASK['4'] ?? 0));
  holes.push(...digitSegmentPaths(x6, y, DIGIT_MASK['6'] ?? 0));
  return holes.join(' ');
}

const ICON_PATH_D = `${clockSilhouettePath()} ${displayHolePaths()}`;

/** Digital clock screen: alarm-clock body with static 9:46 seven-segment display. */
export const DigitalClockScreenIcon = createSvgIcon(
  <path fill="currentColor" fillRule="evenodd" d={ICON_PATH_D} />,
  'DigitalClockScreen',
);
