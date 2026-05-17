import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/trivia/trivia_slide_widget.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/seed/tables/interests_trivia_seed.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

/// Mirrors [ScreenRotator] slide body: Center → Column(mainAxisSize.min) → trivia.
void main() {
  testWidgets('TriviaSlideWidget lays out inside shrink-wrap Column', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultInterestsTrivia(db);
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
          body: Container(
            color: Colors.grey,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TriviaSlideWidget(
                    db: db,
                    blobs: FakeBlobStore(),
                    slide: slide,
                    spec: spec,
                    theme: ThemeData.light(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 + 2?'), findsOneWidget);

    await db.close();
  });
}
