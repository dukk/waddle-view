import 'package:drift/drift.dart'
    show CustomExpression, Expression, OrderingTerm;

import '../curator/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import '../persistence/database.dart';

/// Curated joke id from [slide], else random from [db] (optional [categoryId]).
Future<Joke?> loadJokeForSlide(
  AppDatabase db,
  ParsedWidgetSpec spec,
  ResolvedSlide slide,
) async {
  final curatedId = slide.randomChoices[spec.choiceKey];
  if (curatedId != null && curatedId.isNotEmpty) {
    return (db.select(db.jokes)..where(
          (t) => Expression.and([
            t.id.equals(curatedId),
            t.suppressed.equals(false),
          ]),
        ))
        .getSingleOrNull();
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
  return (q
        ..orderBy([
          (t) => OrderingTerm(expression: const CustomExpression('random()')),
        ])
        ..limit(1))
      .getSingleOrNull();
}

/// Curated trivia id from [slide], else random from [db] (optional [categoryId]).
Future<TriviaQuestion?> loadTriviaForSlide(
  AppDatabase db,
  ParsedWidgetSpec spec,
  ResolvedSlide slide,
) async {
  final curatedId = slide.randomChoices[spec.choiceKey];
  if (curatedId != null && curatedId.isNotEmpty) {
    return (db.select(db.triviaQuestions)
          ..where(
            (t) => Expression.and([
              t.id.equals(curatedId),
              t.suppressed.equals(false),
            ]),
          ))
        .getSingleOrNull();
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
  return (q
        ..orderBy([
          (t) => OrderingTerm(expression: const CustomExpression('random()')),
        ])
        ..limit(1))
      .getSingleOrNull();
}
