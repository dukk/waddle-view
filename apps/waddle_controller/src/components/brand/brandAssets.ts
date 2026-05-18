export const BRAND_HEADSHOT_SRC = '/brand/headshot.svg';
export const BRAND_MASCOT_SRC = '/brand/mascot.svg';

export type BrandMarkVariant = 'headshot' | 'mascot';
export type BrandMarkSize = 'sm' | 'md' | 'lg';

const SIZE_PX: Record<BrandMarkSize, number> = {
  sm: 32,
  md: 96,
  lg: 160,
};

export function brandMarkSrc(variant: BrandMarkVariant): string {
  return variant === 'headshot' ? BRAND_HEADSHOT_SRC : BRAND_MASCOT_SRC;
}

export function brandMarkAlt(variant: BrandMarkVariant): string {
  return variant === 'headshot' ? 'Waddle View mascot headshot' : 'Waddle View mascot';
}

export function brandMarkSizePx(size: BrandMarkSize): number {
  return SIZE_PX[size];
}
