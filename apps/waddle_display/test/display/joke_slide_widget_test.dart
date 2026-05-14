import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/joke/joke_slide_widget.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/seed/tables/content_categories_seed.dart';
import 'package:waddle_shared/seed/tables/joke_categories_seed.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  testWidgets('shows setup then punchline after half dwellMs', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);
    await ensureDefaultContentCategories(db);
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 't_joke_1',
            categoryId: 'dad',
            setup: 'Why did the chicken cross the road?',
            punchline: 'To get to the other side.',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'jokes',
      dwellMs: 1000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'joke',
      slot: 'main',
      config: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: JokeSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.text('Dad jokes'), findsOneWidget);
    expect(find.text('Why did the chicken cross the road?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('joke_punchline_progress')),
      findsOneWidget,
    );
    final punchlineFinder = find.text('To get to the other side.');
    final animFinder = find.ancestor(
      of: punchlineFinder,
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(animFinder).opacity, 0);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(tester.widget<AnimatedOpacity>(animFinder).opacity, 1);
    expect(
      find.byKey(const ValueKey<String>('joke_punchline_progress')),
      findsOneWidget,
    );

    await db.close();
  });

  testWidgets('uses curated joke id from slide.randomChoices', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);
    await ensureDefaultContentCategories(db);
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 't_joke_a',
            categoryId: 'dad',
            setup: 'First',
            punchline: 'P1',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 't_joke_b',
            categoryId: 'dad',
            setup: 'Second curated',
            punchline: 'P2',
            createdAtMs: DateTime.fromMillisecondsSinceEpoch(2),
          ),
        );

    final slide = ResolvedSlide(
      screenId: 'jokes',
      dwellMs: 1000,
      layoutJson: '{}',
      randomChoices: const {'main_joke': 't_joke_b'},
    );
    const spec = ParsedWidgetSpec(
      type: 'joke',
      slot: 'main',
      config: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: JokeSlideWidget(
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

    expect(find.text('Dad jokes'), findsOneWidget);
    expect(find.text('Second curated'), findsOneWidget);
    expect(find.text('First'), findsNothing);

    await db.close();
  });

  testWidgets('empty jokes shows placeholder', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);
    await ensureDefaultContentCategories(db);

    final slide = ResolvedSlide(
      screenId: 'jokes',
      dwellMs: 5000,
      layoutJson: '{}',
    );
    const spec = ParsedWidgetSpec(
      type: 'joke',
      slot: 'main',
      config: {},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: JokeSlideWidget(
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

    expect(find.text('No jokes yet'), findsOneWidget);

    await db.close();
  });
}
