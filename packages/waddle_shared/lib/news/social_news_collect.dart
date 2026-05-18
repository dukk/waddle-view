import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../blob/blob_store.dart';
import '../collect/data_write_context.dart';
import '../curation/reject_filter_context.dart';
import '../net/http_debug_uri.dart';
import '../persistence/database.dart';
import '../persistence/tables.dart';
import 'news_article_id.dart';
import 'social_news_post.dart';

String socialNewsTitleFromText(String text, {required String fallback}) {
  final msg = text.trim();
  if (msg.isEmpty) {
    return fallback;
  }
  const maxLen = 200;
  if (msg.length <= maxLen) {
    return msg;
  }
  return '${msg.substring(0, maxLen - 1)}…';
}

Future<void> upsertSocialNewsPost(
  DataWriteContext ctx, {
  required String sourceType,
  required String sourceId,
  required SocialNewsPost post,
  required int nowMs,
  required RejectFilterContext rejectCtx,
  required http.Client httpClient,
  required String imageBlobPrefix,
  required String fallbackTitle,
}) async {
  final articleId = newsArticleId(sourceType, sourceId, post.id);
  final existing = await (ctx.db.select(ctx.db.news)
        ..where((t) => t.id.equals(articleId)))
      .getSingleOrNull();
  var imageKey = existing?.imageBlobKey;
  if (post.imageUrl != null &&
      post.imageUrl!.isNotEmpty &&
      imageKey == null) {
    imageKey = await _downloadAndStoreImage(
      ctx,
      httpClient: httpClient,
      nowMs: nowMs,
      sourceId: sourceId,
      articleId: articleId,
      imageUrl: post.imageUrl!,
      blobPrefix: imageBlobPrefix,
    );
  }

  final title = socialNewsTitleFromText(post.text, fallback: fallbackTitle);
  final summary =
      post.text.trim().length > title.length ? post.text.trim() : null;
  final isBlocked = rejectCtx.isBlockedAny([title, summary]);
  final suppressedForInsert = (existing?.suppressed ?? false) || isBlocked;

  await ctx.db.into(ctx.db.news).insert(
        NewsCompanion.insert(
          id: articleId,
          sourceType: sourceType,
          sourceId: sourceId,
          guid: post.id,
          title: title,
          link: post.link,
          summary: Value(summary),
          publishedAt: DateTime.fromMillisecondsSinceEpoch(
            post.createdAtMs,
            isUtc: true,
          ),
          fetchedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
          imageBlobKey: Value(imageKey),
          suppressed: Value(suppressedForInsert),
        ),
        onConflict: DoUpdate(
          (old) => NewsCompanion(
            sourceType: Value(sourceType),
            sourceId: Value(sourceId),
            guid: Value(post.id),
            title: Value(title),
            link: Value(post.link),
            summary: Value(summary),
            publishedAt: Value(
              DateTime.fromMillisecondsSinceEpoch(
                post.createdAtMs,
                isUtc: true,
              ),
            ),
            fetchedAt: Value(DateTime.fromMillisecondsSinceEpoch(nowMs)),
            imageBlobKey: Value(imageKey),
            suppressed: isBlocked ? const Value(true) : const Value.absent(),
          ),
        ),
      );
}

Future<String?> _downloadAndStoreImage(
  DataWriteContext ctx, {
  required http.Client httpClient,
  required int nowMs,
  required String sourceId,
  required String articleId,
  required String imageUrl,
  required String blobPrefix,
}) async {
  try {
    final imageUri = Uri.parse(imageUrl);
    ctx.diagnostics.provider(
      '$blobPrefix: GET image article=$articleId '
      '${safeHttpUriForLog(imageUri)}',
    );
    final res = await httpClient.get(imageUri);
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      return null;
    }
    final logicalKey = '$blobPrefix/$sourceId/$articleId/image';
    final ref = await ctx.blobs.putBytes(
      res.bodyBytes,
      logicalKey: logicalKey,
    );
    final mime =
        res.headers['content-type']?.split(';').first.trim() ?? 'image/jpeg';
    await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
          BlobMetadataCompanion.insert(
            blobKey: logicalKey,
            sha256: ref.storageKey.split('/').last,
            relativePath: ref.storageKey,
            bytes: res.bodyBytes.length,
            mimeType: Value(mime),
            capturedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
          ),
        );
    return logicalKey;
  } on Object catch (e, st) {
    ctx.diagnostics.providerFail('$blobPrefix: image article=$articleId', e, st);
    return null;
  }
}

Future<void> pruneSocialNewsArticles(
  DataWriteContext ctx, {
  required String sourceType,
  required String sourceId,
  required int maxArticles,
}) async {
  if (maxArticles < 1) {
    return;
  }
  final rows = await (ctx.db.select(ctx.db.news)
        ..where(
          (t) => t.sourceType.equals(sourceType) & t.sourceId.equals(sourceId),
        )
        ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)]))
      .get();
  final nonsuppressed = rows.where((r) => !r.suppressed).toList();
  if (nonsuppressed.length <= maxArticles) {
    return;
  }
  for (final a in nonsuppressed.sublist(maxArticles)) {
    await deleteSocialNewsArticle(ctx, a);
  }
}

Future<void> deleteSocialNewsArticle(DataWriteContext ctx, NewsArticle a) async {
  final key = a.imageBlobKey;
  if (key != null && key.isNotEmpty) {
    final meta = await (ctx.db.select(ctx.db.blobMetadata)
          ..where((t) => t.blobKey.equals(key)))
        .getSingleOrNull();
    if (meta != null) {
      await ctx.blobs.delete(BlobRef(meta.relativePath));
      await (ctx.db.delete(ctx.db.blobMetadata)
            ..where((t) => t.blobKey.equals(key)))
          .go();
    }
  }
  await (ctx.db.delete(ctx.db.news)..where((t) => t.id.equals(a.id))).go();
}

/// Non-RSS news rows use [News.sourceId] as the curator category slug.
bool newsSourceUsesSourceIdAsCategory(String sourceType) =>
    sourceType != kNewsSourceTypeRss;
