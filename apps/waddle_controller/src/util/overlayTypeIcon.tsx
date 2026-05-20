import type { SvgIconProps } from '@mui/material/SvgIcon';
import AutoAwesomeIcon from '@mui/icons-material/AutoAwesome';
import CelebrationIcon from '@mui/icons-material/Celebration';
import ImageIcon from '@mui/icons-material/Image';
import OpenInFullIcon from '@mui/icons-material/OpenInFull';
import HighlightOutlinedIcon from '@mui/icons-material/HighlightOutlined';
import CalendarMonthIcon from '@mui/icons-material/CalendarMonth';
import EventNoteIcon from '@mui/icons-material/EventNote';
import Schedule from '@mui/icons-material/Schedule';
import PhotoLibraryIcon from '@mui/icons-material/PhotoLibrary';
import ShowChartIcon from '@mui/icons-material/ShowChart';
import QrCode2Icon from '@mui/icons-material/QrCode2';
import TerminalIcon from '@mui/icons-material/Terminal';
import ToysOutlinedIcon from '@mui/icons-material/ToysOutlined';
import type { ElementType } from 'react';
import { DigitalClockScreenIcon } from '@/icons/DigitalClockScreenIcon';

const OVERLAY_TYPE_ICONS: Record<string, ElementType> = {
  shape_rain: AutoAwesomeIcon,
  hearts_rain: AutoAwesomeIcon,
  birthday_confetti: CelebrationIcon,
  bouncing_message: OpenInFullIcon,
  falling_images: ImageIcon,
  matrix_rain: TerminalIcon,
  edge_glow: HighlightOutlinedIcon,
  floating_balloons: ToysOutlinedIcon,
  static_image: ImageIcon,
  digital_clock: DigitalClockScreenIcon,
  analog_clock: Schedule,
  calendar_month: CalendarMonthIcon,
  calendar_upcoming: EventNoteIcon,
  stock_quote: ShowChartIcon,
  photo_slideshow: PhotoLibraryIcon,
  qr_code: QrCode2Icon,
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
