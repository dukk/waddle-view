import type { SvgIconProps } from '@mui/material/SvgIcon';
import type { SlideScreenPreviewKind } from '@/util/programTelemetry';
import { AdminSetupScreenIcon } from './AdminSetupScreenIcon';
import { CalendarScreenIcon } from './CalendarScreenIcon';
import { ClockScreenIcon } from './ClockScreenIcon';
import { ControllerInviteScreenIcon } from './ControllerInviteScreenIcon';
import { DataHealthScreenIcon } from './DataHealthScreenIcon';
import { JokeScreenIcon } from './JokeScreenIcon';
import { LocalApiScreenIcon } from './LocalApiScreenIcon';
import { PhotoCollageScreenIcon } from './PhotoCollageScreenIcon';
import { PhotoScreenIcon } from './PhotoScreenIcon';
import { RssArticleScreenIcon } from './RssArticleScreenIcon';
import { RssColumnsScreenIcon } from './RssColumnsScreenIcon';
import { RssStackScreenIcon } from './RssStackScreenIcon';
import { StaticTextScreenIcon } from './StaticTextScreenIcon';
import { StockScreenIcon } from './StockScreenIcon';
import { TriviaScreenIcon } from './TriviaScreenIcon';
import { VideoScreenIcon } from './VideoScreenIcon';
import { WeatherScreenIcon } from './WeatherScreenIcon';
import { WifiScreenIcon } from './WifiScreenIcon';

const ICONS: Record<SlideScreenPreviewKind, typeof JokeScreenIcon> = {
  static_text: StaticTextScreenIcon,
  joke: JokeScreenIcon,
  trivia: TriviaScreenIcon,
  wifi: WifiScreenIcon,
  clock: ClockScreenIcon,
  calendar: CalendarScreenIcon,
  news: RssArticleScreenIcon,
  news_columns: RssColumnsScreenIcon,
  news_stack: RssStackScreenIcon,
  local_api: LocalApiScreenIcon,
  admin_setup: AdminSetupScreenIcon,
  controller_invite: ControllerInviteScreenIcon,
  weather: WeatherScreenIcon,
  stock: StockScreenIcon,
  data_health: DataHealthScreenIcon,
  photo: PhotoScreenIcon,
  photo_collage: PhotoCollageScreenIcon,
  video: VideoScreenIcon,
};

export function SlideScreenPreviewIcon({
  kind,
  ...props
}: { kind: SlideScreenPreviewKind } & SvgIconProps) {
  const Icon = ICONS[kind];
  return <Icon {...props} />;
}
