import 'dart:typed_data';

import 'package:drift/drift.dart' show Expression, OrderingTerm, Value;

import 'package:waddle_shared/curation/reject_filter_context.dart';

import '../../../blob/blob_store.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';

RssArticle _censorArticle(RssArticle article, RejectFilterContext ctx) {
  if (ctx.isEmpty) {
    return article;
  }
  return article.copyWith(
    title: ctx.censor(article.title),
    summary: Value(
      article.summary == null ? null : ctx.censor(article.summary!),
    ),
  );
}

/// Loads an RSS row for [choiceKey] in [slide.randomChoices], or picks the
/// best-ranked article not in [excludeArticleIds] (same ranking as the single
/// [rss_article] slide and multi-article layouts such as [rss_article_columns]
/// / [rss_article_stack]). Title and summary are passed through the curator's
/// [RejectFilterContext] so configured `censor` terms are masked transiently
/// in memory.
Future<RssArticle?> loadRssArticleForSlideChoice(
  AppDatabase db,
  ParsedWidgetSpec spec,
  ResolvedSlide slide,
  String choiceKey,
  Set<String> excludeArticleIds, {
  RejectFilterContext? rejectCtx,
}) async {
  final ctx = rejectCtx ?? await RejectFilterContext.loadFromDb(db);
  final curatedId = slide.randomChoices[choiceKey];
  if (curatedId != null &&
      curatedId.isNotEmpty &&
      !excludeArticleIds.contains(curatedId)) {
    final row = await (db.select(
      db.rssArticles,
    )..where(
          (t) => Expression.and([
            t.id.equals(curatedId),
            t.suppressed.equals(false),
          ]),
        ))
        .getSingleOrNull();
    return row == null ? null : _censorArticle(row, ctx);
  }
  final feedId = spec.config['feedId'] as String?;
  final q = db.select(db.rssArticles);
  if (feedId != null && feedId.isNotEmpty) {
    q.where(
      (t) => Expression.and([
        t.feedId.equals(feedId),
        t.suppressed.equals(false),
      ]),
    );
  } else {
    q.where((t) => t.suppressed.equals(false));
  }
  final articles =
      await (q
            ..orderBy([
              (t) => OrderingTerm.desc(t.publishedAt),
              (t) => OrderingTerm.desc(t.fetchedAt),
            ])
            ..limit(200))
          .get();
  final filtered = articles
      .where((a) => !excludeArticleIds.contains(a.id))
      .toList();
  if (filtered.isEmpty) {
    return null;
  }

  final imageKeys = <String>{
    for (final a in filtered)
      if ((a.imageBlobKey ?? '').trim().isNotEmpty) a.imageBlobKey!.trim(),
  };
  final qualityByBlobKey = <String, int>{};
  if (imageKeys.isNotEmpty) {
    final blobs = await (db.select(
      db.blobMetadata,
    )..where((t) => t.blobKey.isIn(imageKeys.toList()))).get();
    for (final b in blobs) {
      qualityByBlobKey[b.blobKey] = b.bytes;
    }
  }

  filtered.sort((a, b) {
    final aKey = (a.imageBlobKey ?? '').trim();
    final bKey = (b.imageBlobKey ?? '').trim();
    final aScore = aKey.isEmpty ? 0 : (qualityByBlobKey[aKey] ?? 0);
    final bScore = bKey.isEmpty ? 0 : (qualityByBlobKey[bKey] ?? 0);
    if (aScore != bScore) {
      return bScore.compareTo(aScore);
    }
    if (a.publishedAt != b.publishedAt) {
      return b.publishedAt.compareTo(a.publishedAt);
    }
    return b.fetchedAt.compareTo(a.fetchedAt);
  });
  return _censorArticle(filtered.first, ctx);
}

/// Result of loading an RSS article thumbnail from [BlobStore].
final class RssArticleImageLoad {
  /// No image reference, missing metadata, or empty file on disk.
  const RssArticleImageLoad.absent() : bytes = null, blobReadFailed = false;

  const RssArticleImageLoad.ok(Uint8List data)
    : bytes = data,
      blobReadFailed = false;

  /// [BlobStore.readBytes] threw (for example I/O or missing backing file).
  const RssArticleImageLoad.blobReadFailed()
    : bytes = null,
      blobReadFailed = true;

  final Uint8List? bytes;
  final bool blobReadFailed;
}

Future<RssArticleImageLoad> loadRssArticleImage(
  AppDatabase db,
  BlobStore blobs,
  RssArticle article,
) async {
  final key = article.imageBlobKey;
  if (key == null || key.isEmpty) {
    return const RssArticleImageLoad.absent();
  }
  final meta = await (db.select(
    db.blobMetadata,
  )..where((t) => t.blobKey.equals(key))).getSingleOrNull();
  if (meta == null) {
    return const RssArticleImageLoad.absent();
  }
  try {
    final raw = await blobs.readBytes(BlobRef(meta.relativePath));
    if (raw.isEmpty) {
      return const RssArticleImageLoad.absent();
    }
    return RssArticleImageLoad.ok(Uint8List.fromList(raw));
  } catch (_) {
    return const RssArticleImageLoad.blobReadFailed();
  }
}

/// Category id for RSS slide chrome: curated program key, else feed category.
Future<String?> resolveRssDisplayCategoryId(
  AppDatabase db,
  ResolvedSlide slide,
  RssArticle? article,
) async {
  final fromSlide =
      slide.randomChoices[ScreenProgramCurator.rssScreenCategoryChoiceKey];
  if (fromSlide != null && fromSlide.isNotEmpty) {
    return fromSlide;
  }
  if (article == null) {
    return null;
  }
  final feed = await (db.select(
    db.rssFeedSources,
  )..where((t) => t.id.equals(article.feedId))).getSingleOrNull();
  final c = feed?.category.trim();
  if (c == null || c.isEmpty) {
    return 'general';
  }
  return c;
}

Future<String?> resolveRssArticleSourceLabel(
  AppDatabase db,
  RssArticle? article,
) async {
  if (article == null) {
    return null;
  }
  final feed = await (db.select(
    db.rssFeedSources,
  )..where((t) => t.id.equals(article.feedId))).getSingleOrNull();
  final feedTitle = feed?.title?.trim();
  if (feedTitle != null && feedTitle.isNotEmpty) {
    return feedTitle;
  }
  final feedUrl = feed?.url.trim() ?? '';
  if (feedUrl.isNotEmpty) {
    final host = Uri.tryParse(feedUrl)?.host.trim() ?? '';
    if (host.isNotEmpty) {
      return host;
    }
  }
  final feedId = article.feedId.trim();
  if (feedId.isNotEmpty) {
    return feedId;
  }
  return null;
}
