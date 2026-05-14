import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/trivia/trivia_slide_timing.dart';
import 'package:waddle_display/display/screens/trivia/trivia_slide_widget.dart';
import 'package:waddle_display/display/screens/trivia/trivia_strike_animation.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/seed/tables/content_categories_seed.dart';
import 'package:waddle_shared/seed/tables/trivia_categories_seed.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  test('triviaShuffleOrderForTesting yields A–D permutation', () {
    expect(
      triviaShuffleOrderForTesting(Random(1)).toSet(),
      equals({'A', 'B', 'C', 'D'}),
    );
  });

  test('triviaUniformOptionRowHeight matches longest wrapping option', () {
    const style = TextStyle(fontSize: 20);
    final long = 'x' * 60;
    final hUniform = triviaUniformOptionRowHeightForTesting(
      innerRowWidth: 180,
      optionTexts: ['ok', long],
      optionStyle: style,
      textScaler: TextScaler.noScaling,
      s: 1.0,
    );
    final hLongOnly = triviaUniformOptionRowHeightForTesting(
      innerRowWidth: 180,
      optionTexts: [long],
      optionStyle: style,
      textScaler: TextScaler.noScaling,
      s: 1.0,
    );
    expect(hUniform, hLongOnly);
    final hShortOnly = triviaUniformOptionRowHeightForTesting(
      innerRowWidth: 180,
      optionTexts: const ['ok', 'no'],
      optionStyle: style,
      textScaler: TextScaler.noScaling,
      s: 1.0,
    );
    expect(hUniform, greaterThan(hShortOnly));
  });

  test('triviaUniformOptionGeometry shrinks inner width for short options', () {
    const style = TextStyle(fontSize: 20);
    final g = triviaUniformOptionGeometryForTesting(
      maxInnerRowWidth: 400,
      optionTexts: const ['2', '3', '4', '5'],
      optionStyle: style,
      textScaler: TextScaler.noScaling,
      s: 1.0,
    );
    expect(g.innerRowWidth, lessThan(400));
    expect(g.rowHeight, greaterThan(0));
  });

  test('triviaStrikeDet01 is in [0, 1) and stable for same inputs', () {
    expect(triviaStrikeDet01(99, 3), triviaStrikeDet01(99, 3));
    expect(triviaStrikeDet01(99, 3), greaterThanOrEqualTo(0.0));
    expect(triviaStrikeDet01(99, 3), lessThan(1.0));
  });

  testWidgets('shows question, progress bar, then marks wrong answers', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultTriviaCategories(db);
    await ensureDefaultContentCategories(db);
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 't1',
            categoryId: 'science',
            question: '2 + 2?',
            optionA: '3',
            optionB: 'Four',
            optionC: '5',
            optionD: '22',
            correctOption: 'B',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'trivia',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'trivia',
      slot: 'main',
      config: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: TriviaSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Science'), findsOneWidget);
    expect(find.text('2 + 2?'), findsOneWidget);
    expect(find.text('Four'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('trivia_reveal_progress')),
      findsOneWidget,
    );

    final answerBefore = tester.widget<Text>(find.text('Four'));
    expect(answerBefore.style?.fontWeight, isNot(FontWeight.w700));

    final windowMs = triviaEliminationWindowMs(slide.dwellMs);
    final endMs = triviaEliminationEndMs(windowMs);
    await tester.pump(Duration(milliseconds: endMs + 400));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('Four'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> &&
            k.value.startsWith('trivia_strike_cross_');
      }),
      findsNWidgets(3),
    );
    final crossPaint = tester.widget<CustomPaint>(
      find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> &&
            k.value.startsWith('trivia_strike_cross_');
      }).first,
    );
    expect(crossPaint.painter, isA<TriviaStrikeOverlayPainter>());
    expect(
      (crossPaint.painter! as TriviaStrikeOverlayPainter).kind,
      TriviaStrikeAnimationKind.scribbleOut,
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('trivia_reveal_progress')),
      findsOneWidget,
    );

    final answerAfter = tester.widget<Text>(find.text('Four'));
    expect(answerAfter.style?.fontWeight, FontWeight.w600);
    expect(
      find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> &&
            k.value.startsWith('trivia_correct_reveal_');
      }),
      findsOneWidget,
    );

    await db.close();
  });

  testWidgets('short options use two-column grid key', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultTriviaCategories(db);
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 't1',
            categoryId: 'science',
            question: 'Pick one',
            optionA: 'aa',
            optionB: 'bb',
            optionC: 'cc',
            optionD: 'dd',
            correctOption: 'A',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'trivia',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'trivia',
      slot: 'main',
      config: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: TriviaSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('trivia_answers_grid')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('trivia_answers_column')),
      findsNothing,
    );

    await db.close();
  });

  testWidgets('long option uses single-column key', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultTriviaCategories(db);
    final long = 'x' * (kTriviaTwoColumnMaxOptionChars + 1);
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 't1',
            categoryId: 'science',
            question: 'Pick one',
            optionA: 'short',
            optionB: long,
            optionC: 'cc',
            optionD: 'dd',
            correctOption: 'A',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'trivia',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'trivia',
      slot: 'main',
      config: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: TriviaSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('trivia_answers_column')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('trivia_answers_grid')),
      findsNothing,
    );

    await db.close();
  });

  testWidgets('shuffled labels match seeded RNG', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultTriviaCategories(db);
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 't1',
            categoryId: 'science',
            question: '2 + 2?',
            optionA: '3',
            optionB: 'Four',
            optionC: '5',
            optionD: '22',
            correctOption: 'B',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'trivia',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'trivia',
      slot: 'main',
      config: {},
    );

    final perm = triviaShuffleOrderForTesting(Random(0));
    final correctLabel = String.fromCharCode(
      'A'.codeUnitAt(0) + perm.indexOf('B'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: TriviaSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
            shuffleRandom: Random(0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(correctLabel), findsOneWidget);
    expect(find.text('Four'), findsOneWidget);

    await db.close();
  });

  testWidgets('empty trivia shows placeholder', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultTriviaCategories(db);

    final slide = ResolvedSlide(
      screenId: 'trivia',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'trivia',
      slot: 'main',
      config: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: TriviaSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No trivia yet'), findsOneWidget);

    await db.close();
  });

  testWidgets('true_false trivia renders two choices and one strike', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultTriviaCategories(db);
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 'tf1',
            categoryId: 'science',
            question: 'The Earth is round.',
            optionA: 'True',
            optionB: 'False',
            optionC: '',
            optionD: '',
            correctOption: 'A',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'trivia',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'trivia',
      slot: 'main',
      config: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: TriviaSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
            shuffleRandom: Random(0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('trivia_answers_true_false')),
      findsOneWidget,
    );
    expect(find.text('True'), findsOneWidget);
    expect(find.text('False'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);

    final windowMs = triviaEliminationWindowMs(slide.dwellMs);
    final endMs = triviaEliminationEndMs(windowMs);
    await tester.pump(Duration(milliseconds: endMs + 400));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> &&
            k.value.startsWith('trivia_strike_cross_');
      }),
      findsOneWidget,
    );
    final tfPaint = tester.widget<CustomPaint>(
      find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> &&
            k.value.startsWith('trivia_strike_cross_');
      }).first,
    );
    expect(
      (tfPaint.painter! as TriviaStrikeOverlayPainter).kind,
      TriviaStrikeAnimationKind.scribbleOut,
    );

    await db.close();
  });

  testWidgets('strikeOutX uses circle close badge not canvas cross', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultTriviaCategories(db);
    await ensureDefaultContentCategories(db);
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 't1',
            categoryId: 'science',
            question: '2 + 2?',
            optionA: '3',
            optionB: 'Four',
            optionC: '5',
            optionD: '22',
            correctOption: 'B',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'trivia',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    final spec = ParsedWidgetSpec(
      type: 'trivia',
      slot: 'main',
      config: <String, dynamic>{'strikeAnimation': 'strikeOutX'},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: TriviaSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final windowMs = triviaEliminationWindowMs(slide.dwellMs);
    final endMs = triviaEliminationEndMs(windowMs);
    await tester.pump(Duration(milliseconds: endMs + 400));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNWidgets(3));
    expect(
      find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> &&
            k.value.startsWith('trivia_strike_cross_');
      }),
      findsNothing,
    );

    await db.close();
  });

  testWidgets('scribbleOut paints scribble strike overlay', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultTriviaCategories(db);
    await ensureDefaultContentCategories(db);
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 't1',
            categoryId: 'science',
            question: '2 + 2?',
            optionA: '3',
            optionB: 'Four',
            optionC: '5',
            optionD: '22',
            correctOption: 'B',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'trivia',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    final spec = ParsedWidgetSpec(
      type: 'trivia',
      slot: 'main',
      config: <String, dynamic>{'strikeAnimation': 'scribbleOut'},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: TriviaSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final windowMs = triviaEliminationWindowMs(slide.dwellMs);
    final endMs = triviaEliminationEndMs(windowMs);
    await tester.pump(Duration(milliseconds: endMs + 400));
    await tester.pumpAndSettle();

    final crossFinder = find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> &&
          k.value.startsWith('trivia_strike_cross_');
    });
    expect(crossFinder, findsNWidgets(3));
    final cp = tester.widget<CustomPaint>(crossFinder.first);
    expect(cp.painter, isA<TriviaStrikeOverlayPainter>());
    expect(
      (cp.painter! as TriviaStrikeOverlayPainter).kind,
      TriviaStrikeAnimationKind.scribbleOut,
    );

    await db.close();
  });
}
