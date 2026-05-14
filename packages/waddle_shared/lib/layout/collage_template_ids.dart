/// Nine-slot asymmetric square grid (two large anchors + seven small squares).
const String kCollageTemplateNineSquareAsymmetric = 'nine_square_asymmetric';

/// Eleven-slot symmetric layout: center landscape hub, portrait spines, small landscapes.
const String kCollageTemplateElevenSymmetricHub = 'eleven_symmetric_hub';

/// Nine-slot mixed portrait / landscape magazine grid.
const String kCollageTemplateNineMixedGrid = 'nine_mixed_grid';

/// Nine-slot “comic” style hub: large center landscape, tall side portraits, corner tiles.
const String kCollageTemplateNineDynamicHub = 'nine_dynamic_hub';

/// Twelve-slot band layout with a circular hero and portrait strips.
const String kCollageTemplateTwelveCircleBand = 'twelve_circle_band';

/// All supported [pexels_photo_collage] `config.template` values.
const Set<String> kKnownCollageTemplateIds = {
  kCollageTemplateNineSquareAsymmetric,
  kCollageTemplateElevenSymmetricHub,
  kCollageTemplateNineMixedGrid,
  kCollageTemplateNineDynamicHub,
  kCollageTemplateTwelveCircleBand,
};
