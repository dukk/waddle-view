import { Box, type SxProps, type Theme } from '@mui/material';
import {
  brandMarkAlt,
  brandMarkSizePx,
  brandMarkSrc,
  type BrandMarkSize,
  type BrandMarkVariant,
} from '@/components/brand/brandAssets';

type Props = {
  variant: BrandMarkVariant;
  size?: BrandMarkSize;
  sx?: SxProps<Theme>;
};

export function WaddleBrandMark({ variant, size = 'md', sx }: Props) {
  const px = brandMarkSizePx(size);

  return (
    <Box
      component="img"
      src={brandMarkSrc(variant)}
      alt={brandMarkAlt(variant)}
      sx={{
        width: px,
        height: px,
        objectFit: 'contain',
        display: 'block',
        flexShrink: 0,
        ...sx,
      }}
    />
  );
}
