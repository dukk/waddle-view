import 'package:drift/drift.dart'
    show CustomExpression, Expression, OrderingTerm;

import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';

Joke _censorJoke(Joke joke, RejectFilterContext ctx) {
  if (ctx.isEmpty) {
    return joke;
  }
  return joke.copyWith(
    setup: ctx.censor(joke.setup),
    punchline: ctx.censor(joke.punchline),
  );
}

TriviaQuestion _censorTrivia(TriviaQuestion q, RejectFilterContext ctx) {
  if (ctx.isEmpty) {
    return q;
  }
  return q.copyWith(
    question: ctx.censor(q.question),
    optionA: ctx.censor(q.optionA),
    optionB: ctx.censor(q.optionB),
    optionC: ctx.censor(q.optionC),
    optionD: ctx.censor(q.optionD),
  );
}

/// Curated joke id from [slide], else random from [db] (optional [categoryId]).
/// Returned text passes through the curator's [RejectFilterContext]: any
/// configured `censor` terms are masked transiently (database row untouched),
/// while `block` terms had already led to `suppressed = true` rows that the
/// query below filters out.
Future<Joke?> loadJokeForSlide(
  AppDatabase db,
  ParsedWidgetSpec spec,
  ResolvedSlide slide, {
  RejectFilterContext? rejectCtx,
}) async {
  final ctx = rejectCtx ?? await RejectFilterContext.loadFromDb(db);
  final curatedId = slide.randomChoices[spec.choiceKey];
  if (curatedId != null && curatedId.isNotEmpty) {
    final row = await (db.select(db.jokes)..where(
          (t) => Expression.and([
            t.id.equals(curatedId),
            t.suppressed.equals(false),
          ]),
        ))
        .getSingleOrNull();
    return row == null ? null : _censorJoke(row, ctx);
  }
  final categoryId = spec.config['categoryId'] as String?;
  final q = db.select(db.jokes);
  if (categoryId != null && categoryId.isNotEmpty) {
    q.where(
      (t) => Expression.and([
        t.categoryId.equals(categoryId),
        t.suppressed.equals(false),
      ]),
    );
  } else {
    q.where((t) => t.suppressed.equals(false));
  }
  final row = await (q
        ..orderBy([
          (t) => OrderingTerm(expression: const CustomExpression('random()')),
        ])
        ..limit(1))
      .getSingleOrNull();
  return row == null ? null : _censorJoke(row, ctx);
}

/// Curated trivia id from [slide], else random from [db] (optional [categoryId]).
/// Returned text passes through the curator's [RejectFilterContext] for
/// transient censor masking; block terms have already filtered out the row.
Future<TriviaQuestion?> loadTriviaForSlide(
  AppDatabase db,
  ParsedWidgetSpec spec,
  ResolvedSlide slide, {
  RejectFilterContext? rejectCtx,
}) async {
  final ctx = rejectCtx ?? await RejectFilterContext.loadFromDb(db);
  final curatedId = slide.randomChoices[spec.choiceKey];
  if (curatedId != null && curatedId.isNotEmpty) {
    final row = await (db.select(db.triviaQuestions)
          ..where(
            (t) => Expression.and([
              t.id.equals(curatedId),
              t.suppressed.equals(false),
            ]),
          ))
        .getSingleOrNull();
    return row == null ? null : _censorTrivia(row, ctx);
  }
  final categoryId = spec.config['categoryId'] as String?;
  final q = db.select(db.triviaQuestions);
  if (categoryId != null && categoryId.isNotEmpty) {
    q.where(
      (t) => Expression.and([
        t.categoryId.equals(categoryId),
        t.suppressed.equals(false),
      ]),
    );
  } else {
    q.where((t) => t.suppressed.equals(false));
  }
  final row = await (q
        ..orderBy([
          (t) => OrderingTerm(expression: const CustomExpression('random()')),
        ])
        ..limit(1))
      .getSingleOrNull();
  return row == null ? null : _censorTrivia(row, ctx);
}
