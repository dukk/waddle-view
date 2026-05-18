import 'package:drift/drift.dart';

import 'database.dart';
import 'tables.dart';

/// One bucket for grouped counts (e.g. RSS articles per feed category).
class CategoryStat {
  const CategoryStat({
    required this.categoryId,
    required this.label,
    required this.count,
  });

  final String categoryId;
  final String label;
  final int count;
}

/// Aggregated SQLite metrics for the data-health slide.
class DatabaseHealthSnapshot {
  const DatabaseHealthSnapshot({
    required this.collectedAt,
    required this.rssArticleTotal,
    required this.rssArticleActive,
    required this.rssArticleSuppressed,
    required this.rssArticlesWithImage,
    required this.rssArticlesWithoutImage,
    required this.rssFeedsEnabled,
    required this.rssFeedsDisabled,
    required this.rssFeedsWithConsecutiveFailures,
    required this.photoTotal,
    required this.photoActive,
    required this.photoSuppressed,
    required this.videoTotal,
    required this.videoActive,
    required this.videoSuppressed,
    required this.jokeTotal,
    required this.jokeActive,
    required this.jokeSuppressed,
    required this.triviaTotal,
    required this.triviaActive,
    required this.triviaSuppressed,
    required this.calendarEventCount,
    required this.blobRowCount,
    required this.blobTotalBytes,
    required this.rssByCategory,
    required this.photosByCategory,
    required this.videosByCategory,
    required this.jokesByCategory,
    required this.triviaByCategory,
  });

  final DateTime collectedAt;

  final int rssArticleTotal;
  final int rssArticleActive;
  final int rssArticleSuppressed;
  final int rssArticlesWithImage;
  final int rssArticlesWithoutImage;

  final int rssFeedsEnabled;
  final int rssFeedsDisabled;
  final int rssFeedsWithConsecutiveFailures;

  final int photoTotal;
  final int photoActive;
  final int photoSuppressed;

  final int videoTotal;
  final int videoActive;
  final int videoSuppressed;

  final int jokeTotal;
  final int jokeActive;
  final int jokeSuppressed;

  final int triviaTotal;
  final int triviaActive;
  final int triviaSuppressed;

  final int calendarEventCount;

  final int blobRowCount;
  final int blobTotalBytes;

  final List<CategoryStat> rssByCategory;
  final List<CategoryStat> photosByCategory;
  final List<CategoryStat> videosByCategory;
  final List<CategoryStat> jokesByCategory;
  final List<CategoryStat> triviaByCategory;
}

int _readInt(QueryRow row, String key) {
  final v = row.data[key];
  if (v == null) {
    return 0;
  }
  if (v is int) {
    return v;
  }
  if (v is BigInt) {
    return v.toInt();
  }
  if (v is num) {
    return v.round();
  }
  return int.tryParse(v.toString()) ?? 0;
}

/// Loads aggregate counts for dashboard / operator health views.
class DatabaseStatsRepository {
  DatabaseStatsRepository(this._db);

  final AppDatabase _db;

  Future<DatabaseHealthSnapshot> load() async {
    final collectedAt = DateTime.now();

    final rssAgg = await _db
        .customSelect(
          '''
SELECT
  COUNT(*) AS total,
  SUM(CASE WHEN NOT suppressed THEN 1 ELSE 0 END) AS active,
  SUM(CASE WHEN suppressed THEN 1 ELSE 0 END) AS suppressed,
  SUM(CASE WHEN image_blob_key IS NOT NULL
      AND LENGTH(TRIM(image_blob_key)) > 0 THEN 1 ELSE 0 END) AS with_image,
  SUM(CASE WHEN image_blob_key IS NULL
      OR LENGTH(TRIM(COALESCE(image_blob_key, ''))) = 0 THEN 1 ELSE 0 END) AS without_image
FROM news
WHERE source_type = '${kNewsSourceTypeRss}'
''',
          readsFrom: {_db.news},
        )
        .getSingle();

    final photoAgg = await _db
        .customSelect(
          '''
SELECT
  COUNT(*) AS total,
  SUM(CASE WHEN NOT suppressed THEN 1 ELSE 0 END) AS active,
  SUM(CASE WHEN suppressed THEN 1 ELSE 0 END) AS suppressed
FROM photos
''',
          readsFrom: {_db.photos},
        )
        .getSingle();

    final videoAgg = await _db
        .customSelect(
          '''
SELECT
  COUNT(*) AS total,
  SUM(CASE WHEN NOT suppressed THEN 1 ELSE 0 END) AS active,
  SUM(CASE WHEN suppressed THEN 1 ELSE 0 END) AS suppressed
FROM videos
''',
          readsFrom: {_db.videos},
        )
        .getSingle();

    final jokeAgg = await _db
        .customSelect(
          '''
SELECT
  COUNT(*) AS total,
  SUM(CASE WHEN NOT suppressed THEN 1 ELSE 0 END) AS active,
  SUM(CASE WHEN suppressed THEN 1 ELSE 0 END) AS suppressed
FROM jokes
''',
          readsFrom: {_db.jokes},
        )
        .getSingle();

    final triviaAgg = await _db
        .customSelect(
          '''
SELECT
  COUNT(*) AS total,
  SUM(CASE WHEN NOT suppressed THEN 1 ELSE 0 END) AS active,
  SUM(CASE WHEN suppressed THEN 1 ELSE 0 END) AS suppressed
FROM trivia_questions
''',
          readsFrom: {_db.triviaQuestions},
        )
        .getSingle();

    final feedAgg = await _db
        .customSelect(
          '''
SELECT
  SUM(CASE WHEN enabled THEN 1 ELSE 0 END) AS enabled,
  SUM(CASE WHEN NOT enabled THEN 1 ELSE 0 END) AS disabled
FROM interests_rss_feeds
''',
          readsFrom: {_db.interestsRssFeeds},
        )
        .getSingle();

    final feedsWithFailuresRow = await _db
        .customSelect(
          '''
SELECT COUNT(*) AS c FROM interests_rss_feeds
WHERE consecutive_failures > 0
''',
          readsFrom: {_db.interestsRssFeeds},
        )
        .getSingle();

    final calendarRow = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM calendar_events',
          readsFrom: {_db.calendarEvents},
        )
        .getSingle();

    final blobRow = await _db
        .customSelect(
          '''
SELECT COUNT(*) AS n, COALESCE(SUM(bytes), 0) AS total_bytes
FROM blob_metadata
''',
          readsFrom: {_db.blobMetadata},
        )
        .getSingle();

    final rssByCategory = await _categoryStats(
      '''
SELECT f.category AS category_id,
       COALESCE(MAX(cc.label), f.category) AS label,
       COUNT(*) AS cnt
FROM news a
INNER JOIN interests_rss_feeds f
  ON f.id = a.source_id AND a.source_type = '${kNewsSourceTypeRss}'
LEFT JOIN curator_categories cc ON cc.id = f.category
GROUP BY f.category
ORDER BY cnt DESC, f.category ASC
''',
      readsFrom: {_db.news, _db.interestsRssFeeds, _db.contentCategories},
    );

    final photosByCategory = await _categoryStats(
      '''
SELECT p.category AS category_id,
       COALESCE(MAX(cc.label), p.category) AS label,
       COUNT(*) AS cnt
FROM photos p
LEFT JOIN curator_categories cc ON cc.id = p.category
GROUP BY p.category
ORDER BY cnt DESC, p.category ASC
''',
      readsFrom: {_db.photos, _db.contentCategories},
    );

    final videosByCategory = await _categoryStats(
      '''
SELECT v.category AS category_id,
       COALESCE(MAX(cc.label), v.category) AS label,
       COUNT(*) AS cnt
FROM videos v
LEFT JOIN curator_categories cc ON cc.id = v.category
GROUP BY v.category
ORDER BY cnt DESC, v.category ASC
''',
      readsFrom: {_db.videos, _db.contentCategories},
    );

    final jokesByCategory = await _categoryStats(
      '''
SELECT j.category_id AS category_id,
       COALESCE(MAX(cc.label), j.category_id) AS label,
       COUNT(*) AS cnt
FROM jokes j
LEFT JOIN curator_categories cc ON cc.id = j.category_id
GROUP BY j.category_id
ORDER BY cnt DESC, j.category_id ASC
''',
      readsFrom: {_db.jokes, _db.contentCategories},
    );

    final triviaByCategory = await _categoryStats(
      '''
SELECT t.category_id AS category_id,
       COALESCE(MAX(cc.label), t.category_id) AS label,
       COUNT(*) AS cnt
FROM trivia_questions t
LEFT JOIN curator_categories cc ON cc.id = t.category_id
GROUP BY t.category_id
ORDER BY cnt DESC, t.category_id ASC
''',
      readsFrom: {_db.triviaQuestions, _db.contentCategories},
    );

    return DatabaseHealthSnapshot(
      collectedAt: collectedAt,
      rssArticleTotal: _readInt(rssAgg, 'total'),
      rssArticleActive: _readInt(rssAgg, 'active'),
      rssArticleSuppressed: _readInt(rssAgg, 'suppressed'),
      rssArticlesWithImage: _readInt(rssAgg, 'with_image'),
      rssArticlesWithoutImage: _readInt(rssAgg, 'without_image'),
      rssFeedsEnabled: _readInt(feedAgg, 'enabled'),
      rssFeedsDisabled: _readInt(feedAgg, 'disabled'),
      rssFeedsWithConsecutiveFailures: _readInt(feedsWithFailuresRow, 'c'),
      photoTotal: _readInt(photoAgg, 'total'),
      photoActive: _readInt(photoAgg, 'active'),
      photoSuppressed: _readInt(photoAgg, 'suppressed'),
      videoTotal: _readInt(videoAgg, 'total'),
      videoActive: _readInt(videoAgg, 'active'),
      videoSuppressed: _readInt(videoAgg, 'suppressed'),
      jokeTotal: _readInt(jokeAgg, 'total'),
      jokeActive: _readInt(jokeAgg, 'active'),
      jokeSuppressed: _readInt(jokeAgg, 'suppressed'),
      triviaTotal: _readInt(triviaAgg, 'total'),
      triviaActive: _readInt(triviaAgg, 'active'),
      triviaSuppressed: _readInt(triviaAgg, 'suppressed'),
      calendarEventCount: _readInt(calendarRow, 'c'),
      blobRowCount: _readInt(blobRow, 'n'),
      blobTotalBytes: _readInt(blobRow, 'total_bytes'),
      rssByCategory: rssByCategory,
      photosByCategory: photosByCategory,
      videosByCategory: videosByCategory,
      jokesByCategory: jokesByCategory,
      triviaByCategory: triviaByCategory,
    );
  }

  Future<List<CategoryStat>> _categoryStats(
    String sql, {
    required Set<TableInfo<Table, dynamic>> readsFrom,
  }) async {
    final rows = await _db.customSelect(sql, readsFrom: readsFrom).get();
    return rows
        .map(
          (r) => CategoryStat(
            categoryId: r.data['category_id']! as String,
            label: r.data['label']! as String,
            count: _readInt(r, 'cnt'),
          ),
        )
        .toList();
  }
}
