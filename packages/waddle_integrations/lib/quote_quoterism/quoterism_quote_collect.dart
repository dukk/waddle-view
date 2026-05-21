import 'package:drift/drift.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'quoterism_category.dart';

Future<void> pruneQuoterismQuotesByRetention(
  DataWriteContext ctx, {
  required int retentionDays,
  required int nowMs,
}) async {
  if (retentionDays <= 0) {
    return;
  }
  final cutoffMs = nowMs - Duration(days: retentionDays).inMilliseconds;
  final cutoff = DateTime.fromMillisecondsSinceEpoch(cutoffMs);
  final rows = await (ctx.db.select(ctx.db.quoterismQuotes)..where(
        (t) => t.fetchedAtMs.isSmallerThanValue(cutoff),
      ))
      .get();
  for (final row in rows) {
    await deleteQuoterismQuote(ctx, row);
  }
}

Future<void> pruneQuoterismQuotesByMaxCount(
  DataWriteContext ctx, {
  required int maxQuotes,
}) async {
  if (maxQuotes < 1) {
    return;
  }
  final rows = await (ctx.db.select(ctx.db.quoterismQuotes)
        ..orderBy([(t) => OrderingTerm.asc(t.fetchedAtMs)]))
      .get();
  if (rows.length <= maxQuotes) {
    return;
  }
  final removeCount = rows.length - maxQuotes;
  for (var i = 0; i < removeCount; i++) {
    await deleteQuoterismQuote(ctx, rows[i]);
  }
}

Future<void> deleteQuoterismQuote(
  DataWriteContext ctx,
  QuoterismQuote row,
) async {
  final key = row.authorImageBlobKey;
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
  await (ctx.db.delete(ctx.db.quoterismQuoteCategories)
        ..where((t) => t.quoteId.equals(row.id)))
      .go();
  await (ctx.db.delete(ctx.db.quoterismQuotes)
        ..where((t) => t.id.equals(row.id)))
      .go();
}

Future<void> upsertQuoterismQuoteCategories(
  DataWriteContext ctx, {
  required String quoteId,
  required List<QuoterismCategoryRef> categories,
}) async {
  await (ctx.db.delete(ctx.db.quoterismQuoteCategories)
        ..where((t) => t.quoteId.equals(quoteId)))
      .go();
  for (final cat in categories) {
    await ensureQuoterismContentCategory(
      ctx.db,
      id: cat.id,
      label: cat.label,
    );
    await ctx.db.into(ctx.db.quoterismQuoteCategories).insert(
          QuoterismQuoteCategoriesCompanion.insert(
            quoteId: quoteId,
            categoryId: cat.id,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

Future<bool> storeQuoterismQuote({
  required DataWriteContext ctx,
  required String quoteId,
  required String text,
  required String? authorId,
  required String? authorName,
  required String? authorSlug,
  required String? authorImageBlobKey,
  required DateTime? quoterismCreatedAt,
  required String integrationId,
  required List<QuoterismCategoryRef> categories,
  required int nowMs,
}) async {
  final rejectCtx = await RejectFilterContext.loadFromDb(ctx.db);
  if (rejectCtx.isBlocked(text)) {
    return false;
  }

  final fetchedAt = DateTime.fromMillisecondsSinceEpoch(nowMs);
  await ctx.db.into(ctx.db.quoterismQuotes).insertOnConflictUpdate(
        QuoterismQuotesCompanion.insert(
          id: quoteId,
          quoteText: text,
          authorId: Value(authorId),
          authorName: Value(authorName),
          authorSlug: Value(authorSlug),
          authorImageBlobKey: Value(authorImageBlobKey),
          quoterismCreatedAtMs: Value(quoterismCreatedAt),
          fetchedAtMs: fetchedAt,
          integrationId: Value(integrationId),
          suppressed: const Value(false),
        ),
      );
  await upsertQuoterismQuoteCategories(
    ctx,
    quoteId: quoteId,
    categories: categories,
  );
  return true;
}
