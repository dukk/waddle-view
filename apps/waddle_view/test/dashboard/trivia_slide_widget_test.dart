import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/curator/screen_program_curator.dart';
import 'package:waddle_view/dashboard/trivia_slide_widget.dart';
import 'package:waddle_view/dashboard/trivia_slide_timing.dart';
import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/seed/trivia_category_seed.dart';

import '../helpers/memory_database.dart';
import '../helpers/fake_blob_store.dart';

void main() {
  test('triviaShuffleOrderForTesting yields A–D permutation', () {
    expect(
      triviaShuffleOrderForTesting(Random(1)).toSet(),
      equals({'A', 'B', 'C', 'D'}),
    );
  });

  testWidgets('shows question then fades wrong answers', (tester) async {
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
            createdAtMs: 1,
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

    expect(find.text('2 + 2?'), findsOneWidget);
    expect(find.text('Four'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('trivia_countdown')), findsOneWidget);
    final countdownText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('trivia_countdown')),
    );
    expect(countdownText.textAlign, TextAlign.center);
    expect((countdownText.style?.fontSize ?? 0) >= 48, isTrue);

    final answerBefore = tester.widget<Text>(find.text('Four'));
    expect(answerBefore.style?.fontWeight, isNot(FontWeight.w700));

    final opacitiesStart = tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .map((w) => w.opacity)
        .toList();
    expect(opacitiesStart.every((o) => o == 1), isTrue);

    final windowMs = triviaEliminationWindowMs(slide.dwellMs);
    final endMs = triviaEliminationEndMs(windowMs);
    await tester.pump(Duration(milliseconds: endMs + 400));
    await tester.pumpAndSettle();

    final opacitiesEnd = tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .toList();
    expect(opacitiesEnd.where((w) => w.opacity == 1).length, 1);
    expect(opacitiesEnd.where((w) => w.opacity == 0).length, 3);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('trivia_countdown')), findsNothing);

    final answerAfter = tester.widget<Text>(find.text('Four'));
    expect(answerAfter.style?.fontWeight, FontWeight.w700);

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
            createdAtMs: 1,
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

  testWidgets('shows category icon when mapped', (tester) async {
    final blobs = FakeBlobStore();
    blobs.seed(
      'blob_trivia_icon',
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2WZ6kAAAAASUVORK5CYII=',
      ),
    );

    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultTriviaCategories(db);
    await db.into(db.triviaQuestions).insert(
          TriviaQuestionsCompanion.insert(
            id: 't_icon',
            categoryId: 'science',
            question: 'Q?',
            optionA: 'A1',
            optionB: 'B1',
            optionC: 'C1',
            optionD: 'D1',
            correctOption: 'B',
            createdAtMs: 1,
          ),
        );
    await db.customStatement(
      "INSERT INTO blob_metadata "
      "(blob_key, sha256, relative_path, bytes, mime_type, captured_at) "
      "VALUES ('blob_trivia_icon', 'blob_trivia_icon', 'blob_trivia_icon', 67, 'image/png', 1)",
    );
    await db.customStatement(
      "INSERT INTO category_icons "
      "(category_type, category_id, blob_key, prompt, generated_by, updated_at_ms) "
      "VALUES ('trivia', 'science', 'blob_trivia_icon', 'p', 'openai', 1)",
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
            blobs: blobs,
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('trivia_category_icon')),
      findsOneWidget,
    );
    await db.close();
  });
}
