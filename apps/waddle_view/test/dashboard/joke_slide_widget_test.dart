import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_view/curator/screen_layout_parse.dart';
import 'package:waddle_view/curator/screen_program_curator.dart';
import 'package:waddle_view/dashboard/joke_slide_widget.dart';
import 'package:waddle_view/persistence/database.dart';
import 'package:waddle_view/seed/joke_category_seed.dart';

import '../helpers/memory_database.dart';
import '../helpers/fake_blob_store.dart';

void main() {
  testWidgets('shows setup then punchline after half dwellMs', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 't_joke_1',
            categoryId: 'dad',
            setup: 'Why did the chicken cross the road?',
            punchline: 'To get to the other side.',
            createdAtMs: 1,
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
    await tester.pumpAndSettle();

    expect(find.text('Why did the chicken cross the road?'), findsOneWidget);
    final punchlineFinder = find.text('To get to the other side.');
    final animFinder = find.ancestor(
      of: punchlineFinder,
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(animFinder).opacity, 0);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(tester.widget<AnimatedOpacity>(animFinder).opacity, 1);

    await db.close();
  });

  testWidgets('uses curated joke id from slide.randomChoices', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 't_joke_a',
            categoryId: 'dad',
            setup: 'First',
            punchline: 'P1',
            createdAtMs: 1,
          ),
        );
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 't_joke_b',
            categoryId: 'dad',
            setup: 'Second curated',
            punchline: 'P2',
            createdAtMs: 2,
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

    expect(find.text('Second curated'), findsOneWidget);
    expect(find.text('First'), findsNothing);

    await db.close();
  });

  testWidgets('empty jokes shows placeholder', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);

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

  testWidgets('shows category icon when mapped', (tester) async {
    final blobs = FakeBlobStore();
    blobs.seed(
      'blob_joke_icon',
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2WZ6kAAAAASUVORK5CYII=',
      ),
    );

    final db = openMemoryDatabase();
    await warmDatabase(db);
    await ensureDefaultJokeCategories(db);
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: 't_joke_icon',
            categoryId: 'dad',
            setup: 'Setup',
            punchline: 'Punchline',
            createdAtMs: 1,
          ),
        );

    await db.customStatement(
      "INSERT INTO blob_metadata "
      "(blob_key, sha256, relative_path, bytes, mime_type, captured_at) "
      "VALUES ('blob_joke_icon', 'blob_joke_icon', 'blob_joke_icon', 67, 'image/png', 1)",
    );
    await db.customStatement(
      "INSERT INTO category_icons "
      "(category_type, category_id, blob_key, prompt, generated_by, updated_at_ms) "
      "VALUES ('joke', 'dad', 'blob_joke_icon', 'p', 'openai', 1)",
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
            blobs: blobs,
            slide: slide,
            spec: spec,
            theme: ThemeData.light(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('joke_category_icon')), findsOneWidget);
    await db.close();
  });
}
