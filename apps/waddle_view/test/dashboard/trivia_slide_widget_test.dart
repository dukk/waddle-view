import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/curator/screen_program_curator.dart';
import 'package:waddle_view/dashboard/trivia_slide_widget.dart';
import 'package:waddle_view/dashboard/trivia_slide_timing.dart';
import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/seed/content_category_seed.dart';
import 'package:waddle_view/seed/trivia_category_seed.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  test('triviaShuffleOrderForTesting yields A–D permutation', () {
    expect(
      triviaShuffleOrderForTesting(Random(1)).toSet(),
      equals({'A', 'B', 'C', 'D'}),
    );
  });

  testWidgets('shows question, progress bar, then strikes wrong answers', (
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
      find.byType(CustomPaint),
      findsWidgets,
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('trivia_reveal_progress')),
      findsNothing,
    );

    final answerAfter = tester.widget<Text>(find.text('Four'));
    expect(answerAfter.style?.fontWeight, FontWeight.w700);

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

    expect(find.text('$correctLabel.'), findsOneWidget);
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
}
