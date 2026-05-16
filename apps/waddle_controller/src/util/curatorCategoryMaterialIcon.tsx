import type { SvgIconComponent } from '@mui/icons-material';
import ArticleOutlined from '@mui/icons-material/ArticleOutlined';
import AttachMoney from '@mui/icons-material/AttachMoney';
import BeachAccess from '@mui/icons-material/BeachAccess';
import CalculateOutlined from '@mui/icons-material/CalculateOutlined';
import CardGiftcard from '@mui/icons-material/CardGiftcard';
import DarkModeOutlined from '@mui/icons-material/DarkModeOutlined';
import EggOutlined from '@mui/icons-material/EggOutlined';
import FavoriteBorder from '@mui/icons-material/FavoriteBorder';
import Flag from '@mui/icons-material/Flag';
import ForestOutlined from '@mui/icons-material/ForestOutlined';
import LabelOutlined from '@mui/icons-material/LabelOutlined';
import LandscapeOutlined from '@mui/icons-material/LandscapeOutlined';
import LocalFloristOutlined from '@mui/icons-material/LocalFloristOutlined';
import MapOutlined from '@mui/icons-material/MapOutlined';
import Memory from '@mui/icons-material/Memory';
import MenuBookOutlined from '@mui/icons-material/MenuBookOutlined';
import MovieOutlined from '@mui/icons-material/MovieOutlined';
import PersonOutline from '@mui/icons-material/PersonOutline';
import Pets from '@mui/icons-material/Pets';
import PhotoCameraOutlined from '@mui/icons-material/PhotoCameraOutlined';
import PhotoLibraryOutlined from '@mui/icons-material/PhotoLibraryOutlined';
import Public from '@mui/icons-material/Public';
import Restaurant from '@mui/icons-material/Restaurant';
import SchoolOutlined from '@mui/icons-material/SchoolOutlined';
import ScienceOutlined from '@mui/icons-material/ScienceOutlined';
import SelfImprovement from '@mui/icons-material/SelfImprovement';
import SentimentSatisfiedAltOutlined from '@mui/icons-material/SentimentSatisfiedAltOutlined';
import SportsSoccer from '@mui/icons-material/SportsSoccer';
import StarsOutlined from '@mui/icons-material/StarsOutlined';
import Terrain from '@mui/icons-material/Terrain';
import WallpaperOutlined from '@mui/icons-material/WallpaperOutlined';
import WaterDropOutlined from '@mui/icons-material/WaterDropOutlined';
import WorkOutline from '@mui/icons-material/WorkOutline';

/** Mirrors `content_category_material_icon.dart` in waddle_display. */
const kCategoryMaterialIconByName: Record<string, SvgIconComponent> = {
  article: ArticleOutlined,
  public: Public,
  flag: Flag,
  memory: Memory,
  attach_money: AttachMoney,
  science: ScienceOutlined,
  photo_library: PhotoLibraryOutlined,
  wallpaper: WallpaperOutlined,
  photo_camera: PhotoCameraOutlined,
  forest: ForestOutlined,
  local_florist: LocalFloristOutlined,
  landscape: LandscapeOutlined,
  beach_access: BeachAccess,
  terrain: Terrain,
  sentiment_satisfied: SentimentSatisfiedAltOutlined,
  favorite: FavoriteBorder,
  pets: Pets,
  school: SchoolOutlined,
  work: WorkOutline,
  card_giftcard: CardGiftcard,
  egg_alt: EggOutlined,
  dark_mode: DarkModeOutlined,
  restaurant: Restaurant,
  calculate: CalculateOutlined,
  map: MapOutlined,
  stars: StarsOutlined,
  movie: MovieOutlined,
  person: PersonOutline,
  sports_soccer: SportsSoccer,
  menu_book: MenuBookOutlined,
  self_improvement: SelfImprovement,
  water: WaterDropOutlined,
};

export function curatorCategoryMaterialIconComponent(
  materialIconName: string | null | undefined,
): SvgIconComponent {
  const key = (materialIconName ?? '').trim();
  return kCategoryMaterialIconByName[key] ?? LabelOutlined;
}
