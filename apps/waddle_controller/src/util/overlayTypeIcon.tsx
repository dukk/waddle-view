import type { SvgIconProps } from '@mui/material/SvgIcon';
import AutoAwesomeIcon from '@mui/icons-material/AutoAwesome';
import CelebrationIcon from '@mui/icons-material/Celebration';
import ImageIcon from '@mui/icons-material/Image';
import OpenInFullIcon from '@mui/icons-material/OpenInFull';
import HighlightOutlinedIcon from '@mui/icons-material/HighlightOutlined';
import TerminalIcon from '@mui/icons-material/Terminal';
import type { ElementType } from 'react';

const OVERLAY_TYPE_ICONS: Record<string, ElementType> = {
  shape_rain: AutoAwesomeIcon,
  hearts_rain: AutoAwesomeIcon,
  birthday_confetti: CelebrationIcon,
  bouncing_message: OpenInFullIcon,
  falling_images: ImageIcon,
  matrix_rain: TerminalIcon,
  edge_glow: HighlightOutlinedIcon,
};

function resolveOverlayTypeIcon(overlayType: string): ElementType | null {
  return OVERLAY_TYPE_ICONS[overlayType.trim()] ?? null;
}

export function OverlayTypeIcon({
  overlayType,
  ...props
}: SvgIconProps & { overlayType: string }) {
  const Icon = resolveOverlayTypeIcon(overlayType);
  if (!Icon) {
    return null;
  }
  return <Icon {...props} />;
}
