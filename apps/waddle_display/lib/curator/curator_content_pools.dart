import '../persistence/database.dart';

/// Optional pixel dimensions for a curated photo (from [BlobMetadata]).
class PhotoCuratorMetric {
  const PhotoCuratorMetric({this.pixelWidth, this.pixelHeight});

  final int? pixelWidth;
  final int? pixelHeight;

  double? get aspectRatio {
    final w = pixelWidth;
    final h = pixelHeight;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return null;
    }
    return w / h;
  }

  int get pixelArea {
    final w = pixelWidth;
    final h = pixelHeight;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return 0;
    }
    return w * h;
  }
}

/// Per-article metrics for news capacity-aware curation.
class RssArticleMetric {
  const RssArticleMetric({
    required this.hasImage,
    required this.summaryLength,
    required this.categoryId,
  });

  /// True when [imageBlobKey] is non-empty on the article row.
  final bool hasImage;

  /// Character length of [RssArticle.summary] (trimmed); 0 if null/empty.
  final int summaryLength;

  /// [RssFeedSources.category] for the article’s feed (slug shared with [ContentCategories.id]).
  final String categoryId;
}

/// IDs grouped for [ScreenProgramCurator.buildProgram] `randomPools`, plus RSS
/// metrics for joint news placement.
///
/// Pool keys: `joke`, `joke:<categoryId>`, `rss`, `rss:<feedId>`,
/// `rss_category:<categoryId>`, `trivia`, `trivia:<categoryId>`,
/// `pexels_photo`, `pexels_photo:<category>`,
/// `pexels_video`, `pexels_video:<category>`.
class CuratorContentPools {
  const CuratorContentPools({
    required this.pools,
    this.rssArticleMetrics = const {},
    this.photoMetrics = const {},
  });

  final Map<String, List<String>> pools;

  /// Article id → metrics for capacity / photo gating (only articles present in DB).
  final Map<String, RssArticleMetric> rssArticleMetrics;

  /// Photo id → optional native dimensions for collage / aspect-aware picks.
  final Map<String, PhotoCuratorMetric> photoMetrics;
}

Future<CuratorContentPools> loadCuratorContentPools(
  AppDatabase db,
) async {
  final out = <String, List<String>>{};
  final rssMetrics = <String, RssArticleMetric>{};

  final jokes = await db.select(db.jokes).get();
  if (jokes.isNotEmpty) {
    final all = <String>[];
    final byCat = <String, List<String>>{};
    for (final j in jokes) {
      all.add(j.id);
      (byCat[j.categoryId] ??= []).add(j.id);
    }
    out['joke'] = all;
    for (final e in byCat.entries) {
      out['joke:${e.key}'] = List<String>.from(e.value);
    }
  }

  final feeds = await db.select(db.rssFeedSources).get();
  final feedById = {for (final f in feeds) f.id: f};

  final articles = await db.select(db.rssArticles).get();
  if (articles.isNotEmpty) {
    final all = <String>[];
    final byFeed = <String, List<String>>{};
    final byContentCategory = <String, List<String>>{};
    for (final a in articles) {
      all.add(a.id);
      (byFeed[a.feedId] ??= []).add(a.id);
      final feed = feedById[a.feedId];
      final cat = (feed?.category ?? 'general').trim();
      final categoryKey = cat.isEmpty ? 'general' : cat;
      (byContentCategory[categoryKey] ??= []).add(a.id);
      final key = (a.imageBlobKey ?? '').trim();
      final summary = (a.summary ?? '').trim();
      rssMetrics[a.id] = RssArticleMetric(
        hasImage: key.isNotEmpty,
        summaryLength: summary.length,
        categoryId: categoryKey,
      );
    }
    out['rss'] = all;
    for (final e in byFeed.entries) {
      out['rss:${e.key}'] = List<String>.from(e.value);
    }
    for (final e in byContentCategory.entries) {
      out['rss_category:${e.key}'] = List<String>.from(e.value);
    }
  }

  final trivia = await db.select(db.triviaQuestions).get();
  if (trivia.isNotEmpty) {
    final all = <String>[];
    final byCat = <String, List<String>>{};
    for (final q in trivia) {
      all.add(q.id);
      (byCat[q.categoryId] ??= []).add(q.id);
    }
    out['trivia'] = all;
    for (final e in byCat.entries) {
      out['trivia:${e.key}'] = List<String>.from(e.value);
    }
  }

  final pexelsPhotos = await db.select(db.photos).get();
  final photoMetrics = <String, PhotoCuratorMetric>{};
  if (pexelsPhotos.isNotEmpty) {
    final all = <String>[];
    final byCat = <String, List<String>>{};
    final blobKeys = pexelsPhotos.map((p) => p.mediaBlobKey).toSet().toList();
    final metaByKey = <String, BlobMetadataData>{};
    if (blobKeys.isNotEmpty) {
      final metaRows = await (db.select(db.blobMetadata)
            ..where((t) => t.blobKey.isIn(blobKeys)))
          .get();
      metaByKey.addAll({for (final m in metaRows) m.blobKey: m});
    }
    for (final p in pexelsPhotos) {
      all.add(p.id);
      (byCat[p.category] ??= []).add(p.id);
      final meta = metaByKey[p.mediaBlobKey];
      photoMetrics[p.id] = PhotoCuratorMetric(
        pixelWidth: meta?.pixelWidth,
        pixelHeight: meta?.pixelHeight,
      );
    }
    out['pexels_photo'] = all;
    for (final e in byCat.entries) {
      out['pexels_photo:${e.key}'] = List<String>.from(e.value);
    }
  }

  final pexelsVideos = await db.select(db.videos).get();
  if (pexelsVideos.isNotEmpty) {
    final all = <String>[];
    final byCat = <String, List<String>>{};
    for (final v in pexelsVideos) {
      all.add(v.id);
      (byCat[v.category] ??= []).add(v.id);
    }
    out['pexels_video'] = all;
    for (final e in byCat.entries) {
      out['pexels_video:${e.key}'] = List<String>.from(e.value);
    }
  }

  return CuratorContentPools(
    pools: out,
    rssArticleMetrics: rssMetrics,
    photoMetrics: photoMetrics,
  );
}
