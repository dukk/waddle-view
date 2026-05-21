import 'package:drift/drift.dart'
    show CustomExpression, Expression, OrderingTerm;

import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'ticker_item.dart';

String quoterismTickerBody(QuoterismQuote quote) {
  final text = quote.quoteText.trim();
  final author = (quote.authorName ?? '').trim();
  if (author.isEmpty) {
    return text;
  }
  return '$text — $author';
}

Future<List<TickerItem>> loadQuoterismTickerItems(
  AppDatabase db, {
  String? categoryId,
  int maxItems = 12,
  RejectFilterContext? rejectCtx,
}) async {
  final ctx = rejectCtx ?? await RejectFilterContext.loadFromDb(db);
  final q = db.select(db.quoterismQuotes)
    ..where((t) => t.suppressed.equals(false));

  final cat = categoryId?.trim();
  if (cat != null && cat.isNotEmpty) {
    final ids = await (db.select(db.quoterismQuoteCategories)
          ..where((t) => t.categoryId.equals(cat)))
        .map((r) => r.quoteId)
        .get();
    if (ids.isEmpty) {
      return const [];
    }
    q.where((t) => t.id.isIn(ids));
  }

  final rows = await (q
        ..orderBy([
          (t) => OrderingTerm(expression: const CustomExpression('random()')),
        ])
        ..limit(maxItems))
      .get();

  return [
    for (final row in rows)
      if (!ctx.isBlocked(row.quoteText))
        TickerItem(
          kind: 'quote',
          body: ctx.censor(quoterismTickerBody(row)),
          sourceId: row.id,
        ),
  ];
}
