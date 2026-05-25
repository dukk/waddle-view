import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/photo_collage_curation.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/photo/photo_collage_slide_widget.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

/// Minimal valid 1×1 PNG (grey pixel).
const _imageBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

void main() {
  testWidgets('collage shows placeholder tiles when no curated photos', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    const spec = ParsedWidgetSpec(
      type: 'photo_collage',
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
          body: PhotoCollageSlideWidget(
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
      type: 'photo_collage',
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
          body: PhotoCollageSlideWidget(
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
        type: 'photo_collage',
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
            body: PhotoCollageSlideWidget(
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

  testWidgets('hides photographer attribution on cells by default', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    final logicalKey = 'pexels/photo/collage/image';
    final ref = await blobs.putBytes(_imageBytes, logicalKey: logicalKey);
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: logicalKey,
            sha256: ref.storageKey.split('/').last,
            relativePath: ref.storageKey,
            bytes: _imageBytes.length,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'c1',
            category: const Value('pexels'),
            mediaBlobKey: logicalKey,
            photographerName: 'Collage Artist',
            photographerUrl: 'https://www.pexels.com/@collage',
            pageUrl: 'https://www.pexels.com/photo/c1/',
            altText: const Value(''),
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'photo_collage',
      slot: 'main',
      config: {'template': kCollageTemplateNineSquareAsymmetric},
    );
    final slide = ResolvedSlide(
      screenId: 'collage',
      dwellMs: 8000,
      layoutJson: '{}',
      randomChoices: const {'main_photo_collage_0': 'c1'},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: PhotoCollageSlideWidget(
            db: db,
            blobs: blobs,
            slide: slide,
            spec: spec,
            theme: ThemeData.dark(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Collage Artist'), findsNothing);
    await db.close();
  });

  testWidgets('shows photographer attribution on cells when enabled', (
    tester,
  ) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    final logicalKey = 'pexels/photo/collage2/image';
    final ref = await blobs.putBytes(_imageBytes, logicalKey: logicalKey);
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: logicalKey,
            sha256: ref.storageKey.split('/').last,
            relativePath: ref.storageKey,
            bytes: _imageBytes.length,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    await db.into(db.photos).insert(
          PhotosCompanion.insert(
            id: 'c2',
            category: const Value('pexels'),
            mediaBlobKey: logicalKey,
            photographerName: 'Collage Artist',
            photographerUrl: 'https://www.pexels.com/@collage',
            pageUrl: 'https://www.pexels.com/photo/c2/',
            altText: const Value(''),
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    const spec = ParsedWidgetSpec(
      type: 'photo_collage',
      slot: 'main',
      config: {
        'template': kCollageTemplateNineSquareAsymmetric,
        'showPhotographerOverlay': true,
      },
    );
    final slide = ResolvedSlide(
      screenId: 'collage',
      dwellMs: 8000,
      layoutJson: '{}',
      randomChoices: const {'main_photo_collage_0': 'c2'},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: PhotoCollageSlideWidget(
            db: db,
            blobs: blobs,
            slide: slide,
            spec: spec,
            theme: ThemeData.dark(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Collage Artist'), findsOneWidget);
    await db.close();
  });
}
