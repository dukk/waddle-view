import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/photo_collage_curation.dart';
import 'package:waddle_display/curator/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/pexels/pexels_photo_collage_slide_widget.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

void main() {
  testWidgets('collage shows placeholder tiles when no curated photos', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    const spec = ParsedWidgetSpec(
      type: 'pexels_photo_collage',
      slot: 'main',
      config: {},
    );
    final slide = ResolvedSlide(
      screenId: 'collage',
      dwellMs: 8000,
      layoutJson: '{}',
      randomChoices: const {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: PexelsPhotoCollageSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.dark(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.image_not_supported_outlined), findsWidgets);
    await db.close();
  });

  testWidgets('unknown template config falls back to default grid', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    const spec = ParsedWidgetSpec(
      type: 'pexels_photo_collage',
      slot: 'main',
      config: {'template': 'not-a-real-template-id'},
    );
    final slide = ResolvedSlide(
      screenId: 'collage',
      dwellMs: 8000,
      layoutJson: '{}',
      randomChoices: const {},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: PexelsPhotoCollageSlideWidget(
            db: db,
            blobs: FakeBlobStore(),
            slide: slide,
            spec: spec,
            theme: ThemeData.dark(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.image_not_supported_outlined), findsWidgets);
    await db.close();
  });

  for (final template in <String>[
    kCollageTemplateElevenSymmetricHub,
    kCollageTemplateNineMixedGrid,
    kCollageTemplateNineDynamicHub,
    kCollageTemplateTwelveCircleBand,
  ]) {
    testWidgets('collage builds layout for template $template', (tester) async {
      final db = openMemoryDatabase();
      await warmDatabase(db);
      final spec = ParsedWidgetSpec(
        type: 'pexels_photo_collage',
        slot: 'main',
        config: {'template': template},
      );
      final slide = ResolvedSlide(
        screenId: 'collage',
        dwellMs: 8000,
        layoutJson: '{}',
        randomChoices: const {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: PexelsPhotoCollageSlideWidget(
              db: db,
              blobs: FakeBlobStore(),
              slide: slide,
              spec: spec,
              theme: ThemeData.dark(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.image_not_supported_outlined), findsWidgets);
      await db.close();
    });
  }
}
