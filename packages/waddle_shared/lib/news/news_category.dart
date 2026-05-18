import '../persistence/database.dart';
import '../persistence/tables.dart';
import 'social_news_collect.dart';

/// Curator / slide category slug for a [NewsArticle].
///
/// RSS rows use [InterestsRssFeeds.category]. Social feed rows use [News.sourceId]
/// (the feed source id) as the category slug.
Future<String> newsCategoryForArticle(
  AppDatabase db,
  NewsArticle article,
) async {
  if (newsSourceUsesSourceIdAsCategory(article.sourceType)) {
    final id = article.sourceId.trim();
    return id.isEmpty ? 'general' : id;
  }
  final feed = await (db.select(db.interestsRssFeeds)
        ..where((t) => t.id.equals(article.sourceId)))
      .getSingleOrNull();
  final cat = (feed?.category ?? 'general').trim();
  return cat.isEmpty ? 'general' : cat;
}
