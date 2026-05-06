import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;

import '../blob/blob_store.dart';
import '../curator/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import '../persistence/database.dart';

/// Loads an RSS row for [choiceKey] in [slide.randomChoices], or picks the
/// best-ranked article not in [excludeArticleIds] (same ranking as the single
/// [rss_article] slide and multi-article layouts such as [rss_article_columns]
/// / [rss_article_stack]).
Future<RssArticle?> loadRssArticleForSlideChoice(
  AppDatabase db,
  ParsedWidgetSpec spec,
  ResolvedSlide slide,
  String choiceKey,
  Set<String> excludeArticleIds,
) async {
  final curatedId = slide.randomChoices[choiceKey];
  if (curatedId != null &&
      curatedId.isNotEmpty &&
      !excludeArticleIds.contains(curatedId)) {
    return (db.select(
      db.rssArticles,
    )..where((t) => t.id.equals(curatedId))).getSingleOrNull();
  }
  final feedId = spec.config['feedId'] as String?;
  final q = db.select(db.rssArticles);
  if (feedId != null && feedId.isNotEmpty) {
    q.where((t) => t.feedId.equals(feedId));
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
  return filtered.first;
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
