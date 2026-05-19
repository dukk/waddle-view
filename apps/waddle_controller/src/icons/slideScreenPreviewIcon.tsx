import type { SvgIconProps } from '@mui/material/SvgIcon';
import type { SvgIconComponent } from '@mui/icons-material';
import AddLink from '@mui/icons-material/AddLink';
import ArticleOutlined from '@mui/icons-material/ArticleOutlined';
import CalendarMonth from '@mui/icons-material/CalendarMonth';
import ChatBubbleOutline from '@mui/icons-material/ChatBubbleOutline';
import DescriptionOutlined from '@mui/icons-material/DescriptionOutlined';
import GridView from '@mui/icons-material/GridView';
import HelpOutline from '@mui/icons-material/HelpOutline';
import ImageOutlined from '@mui/icons-material/ImageOutlined';
import Layers from '@mui/icons-material/Layers';
import MonitorHeart from '@mui/icons-material/MonitorHeart';
import PlayCircleOutline from '@mui/icons-material/PlayCircleOutline';
import Schedule from '@mui/icons-material/Schedule';
import Settings from '@mui/icons-material/Settings';
import Terminal from '@mui/icons-material/Terminal';
import TrendingUp from '@mui/icons-material/TrendingUp';
import ViewCarousel from '@mui/icons-material/ViewCarousel';
import ViewColumn from '@mui/icons-material/ViewColumn';
import WbCloudy from '@mui/icons-material/WbCloudy';
import Wifi from '@mui/icons-material/Wifi';
import type { SlideScreenPreviewKind } from '@/util/programTelemetry';
import { DigitalClockScreenIcon } from './DigitalClockScreenIcon';

// To restore a custom glyph for one kind, replace its entry with a local createSvgIcon component.

/** Stock MUI icons for screen catalog / program-card previews (custom SVGs live in git history). */
const ICONS: Record<SlideScreenPreviewKind, SvgIconComponent> = {
  static_text: DescriptionOutlined,
  joke: ChatBubbleOutline,
  trivia: HelpOutline,
  wifi: Wifi,
  clock: Schedule,
  digital_clock: DigitalClockScreenIcon,
  calendar: CalendarMonth,
  news: ArticleOutlined,
  news_columns: ViewColumn,
  news_stack: Layers,
  local_api: Terminal,
  admin_setup: Settings,
  controller_invite: AddLink,
  weather: WbCloudy,
  stock: TrendingUp,
  data_health: MonitorHeart,
  photo: ImageOutlined,
  photo_collage: GridView,
  video: PlayCircleOutline,
};

export function SlideScreenPreviewIcon({
  kind,
  ...props
}: { kind: SlideScreenPreviewKind } & SvgIconProps) {
  const Icon = ICONS[kind] ?? ViewCarousel;
  return <Icon {...props} />;
}

/** Fallback when `screenTypePreviewKind` is null (unknown screen types). */
export const ScreenCarouselFallbackIcon = ViewCarousel;
