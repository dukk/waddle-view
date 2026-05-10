import 'package:flutter/material.dart';

/// Maps [ContentCategories.materialIconName] from the database to [IconData].
///
/// Unknown names fall back to [Icons.label_outline] so new DB values do not crash UI.
IconData contentCategoryMaterialIcon(String? materialIconName) {
  switch (materialIconName) {
    case 'article':
      return Icons.article_outlined;
    case 'public':
      return Icons.public;
    case 'flag':
      return Icons.flag;
    case 'memory':
      return Icons.memory;
    case 'attach_money':
      return Icons.attach_money;
    case 'science':
      return Icons.science_outlined;
    case 'photo_library':
      return Icons.photo_library_outlined;
    case 'wallpaper':
      return Icons.wallpaper_outlined;
    case 'photo_camera':
      return Icons.photo_camera_outlined;
    case 'forest':
      return Icons.forest_outlined;
    case 'local_florist':
      return Icons.local_florist_outlined;
    case 'landscape':
      return Icons.landscape_outlined;
    case 'beach_access':
      return Icons.beach_access;
    case 'terrain':
      return Icons.terrain;
    case 'sentiment_satisfied':
      return Icons.sentiment_satisfied_alt_outlined;
    case 'favorite':
      return Icons.favorite_border;
    case 'pets':
      return Icons.pets;
    case 'school':
      return Icons.school_outlined;
    case 'work':
      return Icons.work_outline;
    case 'card_giftcard':
      return Icons.card_giftcard;
    case 'egg_alt':
      return Icons.egg_outlined;
    case 'dark_mode':
      return Icons.dark_mode_outlined;
    case 'restaurant':
      return Icons.restaurant;
    case 'calculate':
      return Icons.calculate_outlined;
    case 'map':
      return Icons.map_outlined;
    case 'stars':
      return Icons.stars_outlined;
    case 'movie':
      return Icons.movie_outlined;
    case 'person':
      return Icons.person_outline;
    case 'sports_soccer':
      return Icons.sports_soccer;
    case 'menu_book':
      return Icons.menu_book_outlined;
    case 'self_improvement':
      return Icons.self_improvement;
    case 'water':
      return Icons.water_drop_outlined;
    default:
      return Icons.label_outline;
  }
}
