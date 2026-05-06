/// Default rows for [ContentCategories] (RSS, Pexels, jokes, trivia share [id] strings).
const kContentCategoryDefaults = <ContentCategoryDef>[
  ContentCategoryDef(
    id: 'general',
    label: 'General',
    materialIconName: 'article',
  ),
  ContentCategoryDef(
    id: 'world',
    label: 'World news',
    materialIconName: 'public',
  ),
  ContentCategoryDef(
    id: 'usa',
    label: 'USA news',
    materialIconName: 'flag',
  ),
  ContentCategoryDef(
    id: 'technology',
    label: 'Technology',
    materialIconName: 'memory',
  ),
  ContentCategoryDef(
    id: 'finance',
    label: 'Finance',
    materialIconName: 'attach_money',
  ),
  ContentCategoryDef(
    id: 'science',
    label: 'Science',
    materialIconName: 'science',
  ),
  ContentCategoryDef(
    id: 'pexels',
    label: 'Pexels',
    materialIconName: 'photo_library',
  ),
  ContentCategoryDef(
    id: 'nature',
    label: 'Nature',
    materialIconName: 'forest',
  ),
  ContentCategoryDef(
    id: 'flowers',
    label: 'Flowers',
    materialIconName: 'local_florist',
  ),
  ContentCategoryDef(
    id: 'landscape',
    label: 'Landscape',
    materialIconName: 'landscape',
  ),
  ContentCategoryDef(
    id: 'beach',
    label: 'Beach',
    materialIconName: 'beach_access',
  ),
  ContentCategoryDef(
    id: 'mountains',
    label: 'Mountains',
    materialIconName: 'terrain',
  ),
  ContentCategoryDef(
    id: 'motivational',
    label: 'Motivational',
    materialIconName: 'self_improvement',
  ),
  ContentCategoryDef(
    id: 'aquarium',
    label: 'Aquarium',
    materialIconName: 'water',
  ),
  ContentCategoryDef(
    id: 'dad',
    label: 'Dad jokes',
    materialIconName: 'sentiment_satisfied',
  ),
  ContentCategoryDef(
    id: 'mom',
    label: 'Mom jokes',
    materialIconName: 'favorite',
  ),
  ContentCategoryDef(
    id: 'animal',
    label: 'Animal jokes',
    materialIconName: 'pets',
  ),
  ContentCategoryDef(
    id: 'school',
    label: 'School jokes',
    materialIconName: 'school',
  ),
  ContentCategoryDef(
    id: 'work',
    label: 'Work jokes',
    materialIconName: 'work',
  ),
  ContentCategoryDef(
    id: 'christmas',
    label: 'Christmas',
    materialIconName: 'card_giftcard',
  ),
  ContentCategoryDef(
    id: 'easter',
    label: 'Easter',
    materialIconName: 'egg_alt',
  ),
  ContentCategoryDef(
    id: 'halloween',
    label: 'Halloween',
    materialIconName: 'dark_mode',
  ),
  ContentCategoryDef(
    id: 'thanksgiving',
    label: 'Thanksgiving',
    materialIconName: 'restaurant',
  ),
  ContentCategoryDef(
    id: 'elem_math',
    label: 'Elementary math',
    materialIconName: 'calculate',
  ),
  ContentCategoryDef(
    id: 'world_geo',
    label: 'World geography',
    materialIconName: 'map',
  ),
  ContentCategoryDef(
    id: 'pop_culture',
    label: 'Pop culture',
    materialIconName: 'stars',
  ),
  ContentCategoryDef(
    id: 'movies',
    label: 'Movies',
    materialIconName: 'movie',
  ),
  ContentCategoryDef(
    id: 'celebrities',
    label: 'Celebrities',
    materialIconName: 'person',
  ),
  ContentCategoryDef(
    id: 'sports',
    label: 'Sports',
    materialIconName: 'sports_soccer',
  ),
  ContentCategoryDef(
    id: 'history',
    label: 'History',
    materialIconName: 'menu_book',
  ),
];

/// One canonical dashboard content category (icons: [materialIconName] and/or [iconBlobKey]).
class ContentCategoryDef {
  const ContentCategoryDef({
    required this.id,
    required this.label,
    this.iconBlobKey,
    this.materialIconName,
  });

  final String id;
  final String label;
  final String? iconBlobKey;
  final String? materialIconName;
}
