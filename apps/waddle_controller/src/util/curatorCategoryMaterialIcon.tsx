import type { SvgIconComponent } from '@mui/icons-material';
import AccountCircleOutlined from '@mui/icons-material/AccountCircleOutlined';
import ApartmentOutlined from '@mui/icons-material/ApartmentOutlined';
import ArticleOutlined from '@mui/icons-material/ArticleOutlined';
import AttachMoney from '@mui/icons-material/AttachMoney';
import AutoStoriesOutlined from '@mui/icons-material/AutoStoriesOutlined';
import BeachAccess from '@mui/icons-material/BeachAccess';
import BusinessCenterOutlined from '@mui/icons-material/BusinessCenterOutlined';
import CalculateOutlined from '@mui/icons-material/CalculateOutlined';
import CardGiftcard from '@mui/icons-material/CardGiftcard';
import CheckroomOutlined from '@mui/icons-material/CheckroomOutlined';
import ChildCareOutlined from '@mui/icons-material/ChildCareOutlined';
import ChurchOutlined from '@mui/icons-material/ChurchOutlined';
import CodeOutlined from '@mui/icons-material/CodeOutlined';
import CoffeeOutlined from '@mui/icons-material/CoffeeOutlined';
import DarkModeOutlined from '@mui/icons-material/DarkModeOutlined';
import DevicesOutlined from '@mui/icons-material/DevicesOutlined';
import DirectionsCarOutlined from '@mui/icons-material/DirectionsCarOutlined';
import EggOutlined from '@mui/icons-material/EggOutlined';
import EventOutlined from '@mui/icons-material/EventOutlined';
import FamilyRestroomOutlined from '@mui/icons-material/FamilyRestroomOutlined';
import FavoriteBorder from '@mui/icons-material/FavoriteBorder';
import FitnessCenterOutlined from '@mui/icons-material/FitnessCenterOutlined';
import Flag from '@mui/icons-material/Flag';
import ForestOutlined from '@mui/icons-material/ForestOutlined';
import GavelOutlined from '@mui/icons-material/GavelOutlined';
import GroupsOutlined from '@mui/icons-material/GroupsOutlined';
import HomeOutlined from '@mui/icons-material/HomeOutlined';
import LabelOutlined from '@mui/icons-material/LabelOutlined';
import LandscapeOutlined from '@mui/icons-material/LandscapeOutlined';
import LocalFloristOutlined from '@mui/icons-material/LocalFloristOutlined';
import LocalHospitalOutlined from '@mui/icons-material/LocalHospitalOutlined';
import LunchDiningOutlined from '@mui/icons-material/LunchDiningOutlined';
import ManageSearchOutlined from '@mui/icons-material/ManageSearchOutlined';
import MapOutlined from '@mui/icons-material/MapOutlined';
import Memory from '@mui/icons-material/Memory';
import MenuBookOutlined from '@mui/icons-material/MenuBookOutlined';
import MovieOutlined from '@mui/icons-material/MovieOutlined';
import MusicNoteOutlined from '@mui/icons-material/MusicNoteOutlined';
import PaletteOutlined from '@mui/icons-material/PaletteOutlined';
import PersonOutlined from '@mui/icons-material/PersonOutlined';
import Pets from '@mui/icons-material/Pets';
import PhotoCameraOutlined from '@mui/icons-material/PhotoCameraOutlined';
import PhotoLibraryOutlined from '@mui/icons-material/PhotoLibraryOutlined';
import PodcastsOutlined from '@mui/icons-material/PodcastsOutlined';
import Public from '@mui/icons-material/Public';
import Restaurant from '@mui/icons-material/Restaurant';
import RestaurantMenuOutlined from '@mui/icons-material/RestaurantMenuOutlined';
import SchoolOutlined from '@mui/icons-material/SchoolOutlined';
import ScienceOutlined from '@mui/icons-material/ScienceOutlined';
import SelfImprovement from '@mui/icons-material/SelfImprovement';
import SentimentSatisfiedAltOutlined from '@mui/icons-material/SentimentSatisfiedAltOutlined';
import ShoppingCartOutlined from '@mui/icons-material/ShoppingCartOutlined';
import SportsEsportsOutlined from '@mui/icons-material/SportsEsportsOutlined';
import SportsSoccer from '@mui/icons-material/SportsSoccer';
import StarsOutlined from '@mui/icons-material/StarsOutlined';
import Terrain from '@mui/icons-material/Terrain';
import TvOutlined from '@mui/icons-material/TvOutlined';
import VolunteerActivismOutlined from '@mui/icons-material/VolunteerActivismOutlined';
import WallpaperOutlined from '@mui/icons-material/WallpaperOutlined';
import WaterDropOutlined from '@mui/icons-material/WaterDropOutlined';
import WorkOutlined from '@mui/icons-material/WorkOutlined';
import YardOutlined from '@mui/icons-material/YardOutlined';

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
  work: WorkOutlined,
  card_giftcard: CardGiftcard,
  egg_alt: EggOutlined,
  dark_mode: DarkModeOutlined,
  restaurant: Restaurant,
  calculate: CalculateOutlined,
  map: MapOutlined,
  stars: StarsOutlined,
  movie: MovieOutlined,
  person: PersonOutlined,
  sports_soccer: SportsSoccer,
  menu_book: MenuBookOutlined,
  self_improvement: SelfImprovement,
  water: WaterDropOutlined,
  family_restroom: FamilyRestroomOutlined,
  account_circle: AccountCircleOutlined,
  business_center: BusinessCenterOutlined,
  church: ChurchOutlined,
  volunteer_activism: VolunteerActivismOutlined,
  shopping_cart: ShoppingCartOutlined,
  local_hospital: LocalHospitalOutlined,
  manage_search: ManageSearchOutlined,
  lunch_dining: LunchDiningOutlined,
  restaurant_menu: RestaurantMenuOutlined,
  coffee: CoffeeOutlined,
  code: CodeOutlined,
  devices: DevicesOutlined,
  home: HomeOutlined,
  apartment: ApartmentOutlined,
  music_note: MusicNoteOutlined,
  tv: TvOutlined,
  podcasts: PodcastsOutlined,
  sports_esports: SportsEsportsOutlined,
  auto_stories: AutoStoriesOutlined,
  fitness_center: FitnessCenterOutlined,
  child_care: ChildCareOutlined,
  directions_car: DirectionsCarOutlined,
  yard: YardOutlined,
  checkroom: CheckroomOutlined,
  palette: PaletteOutlined,
  groups: GroupsOutlined,
  gavel: GavelOutlined,
  event: EventOutlined,
};

export function curatorCategoryMaterialIconComponent(
  materialIconName: string | null | undefined,
): SvgIconComponent {
  const key = (materialIconName ?? '').trim();
  return kCategoryMaterialIconByName[key] ?? LabelOutlined;
}
