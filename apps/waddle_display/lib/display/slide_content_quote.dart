import 'package:drift/drift.dart'
    show CustomExpression, Expression, OrderingTerm;

import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';

QuoterismQuote _censorQuote(QuoterismQuote quote, RejectFilterContext ctx) {
  if (ctx.isEmpty) {
    return quote;
  }
  return quote.copyWith(quoteText: ctx.censor(quote.quoteText));
}

Future<Set<String>> _quoteIdsForCategory(
  AppDatabase db,
  String categoryId,
) async {
  final rows = await (db.select(db.quoterismQuoteCategories)
        ..where((t) => t.categoryId.equals(categoryId)))
      .get();
  return rows.map((r) => r.quoteId).toSet();
}

/// Curated quote id from [slide], else random (optional [categoryId]).
Future<QuoterismQuote?> loadQuoteForSlide(
  AppDatabase db,
  ParsedWidgetSpec spec,
  ResolvedSlide slide, {
  RejectFilterContext? rejectCtx,
}) async {
  final ctx = rejectCtx ?? await RejectFilterContext.loadFromDb(db);
  final curatedId = slide.randomChoices[spec.choiceKey];
  if (curatedId != null && curatedId.isNotEmpty) {
    final row = await (db.select(db.quoterismQuotes)
          ..where(
            (t) => Expression.and([
              t.id.equals(curatedId),
              t.suppressed.equals(false),
            ]),
          ))
        .getSingleOrNull();
    return row == null ? null : _censorQuote(row, ctx);
  }

  final categoryId = spec.config['categoryId'] as String?;
  if (categoryId != null && categoryId.isNotEmpty) {
    final ids = await _quoteIdsForCategory(db, categoryId);
    if (ids.isEmpty) {
      return null;
    }
    final row = await (db.select(db.quoterismQuotes)
          ..where(
            (t) => Expression.and([
              t.id.isIn(ids),
              t.suppressed.equals(false),
            ]),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: const CustomExpression('random()')),
          ])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _censorQuote(row, ctx);
  }

  final row = await (db.select(db.quoterismQuotes)
        ..where((t) => t.suppressed.equals(false))
        ..orderBy([
          (t) => OrderingTerm(expression: const CustomExpression('random()')),
        ])
        ..limit(1))
      .getSingleOrNull();
  return row == null ? null : _censorQuote(row, ctx);
}
