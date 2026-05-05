import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/curator/screen_program_curator.dart';
import 'package:waddle_view/dashboard/trivia_slide_widget.dart';
import 'package:waddle_view/dashboard/trivia_slide_timing.dart';
import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/seed/trivia_category_seed.dart';

import '../helpers/memory_database.dart';

void main() {
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
