import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/content_category_slide_header.dart';
import 'package:waddle_display/theme/display_theme.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/seed/tables/interests_jokes_seed.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

/// Valid 1×1 transparent PNG for [Image.memory].
final Uint8List _tinyPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

void main() {
  testWidgets('omits header when category id is null or blank', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    final theme = DisplayTheme.build();
    final blobs = FakeBlobStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ListView(
            children: [
              ContentCategorySlideHeader(
                db: db,
                blobs: blobs,
                theme: theme,
                categoryId: null,
              ),
              ContentCategorySlideHeader(
                db: db,
                blobs: blobs,
                theme: theme,
                categoryId: '   ',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('content_category_slide_header')), findsNothing);
  });

  testWidgets('uses content_categories row label and material icon', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    await db.into(db.contentCategories).insert(
          ContentCategoriesCompanion.insert(
            id: 'ctl_hdr_cat',
            label: 'Catalog header',
            materialIconName: const Value('home'),
          ),
        );
    final theme = DisplayTheme.build();
    final blobs = FakeBlobStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ContentCategorySlideHeader(
            db: db,
            blobs: blobs,
            theme: theme,
            categoryId: 'ctl_hdr_cat',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Catalog header'), findsOneWidget);
    expect(find.byKey(const Key('content_category_slide_header')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('falls back to interests_jokes then interests_trivia labels', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    await ensureDefaultInterestsJokes(db);
    await db.into(db.interestsTrivia).insert(
          InterestsTriviaCompanion.insert(id: 'tr_only', label: 'Trivia only'),
        );
    final theme = DisplayTheme.build();
    final blobs = FakeBlobStore();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ContentCategorySlideHeader(
            db: db,
            blobs: blobs,
            theme: theme,
            categoryId: 'dad',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dad jokes'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ContentCategorySlideHeader(
            db: db,
            blobs: blobs,
            theme: theme,
            categoryId: 'tr_only',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trivia only'), findsOneWidget);
  });

  testWidgets('uses category id as label when no tables match', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    final theme = DisplayTheme.build();
    final blobs = FakeBlobStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ContentCategorySlideHeader(
            db: db,
            blobs: blobs,
            theme: theme,
            categoryId: 'no_such_category_slug',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('no_such_category_slug'), findsOneWidget);
  });

  testWidgets('loads icon bytes from blob metadata when present', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    const relPath = 'icons/cat_blob.bin';
    await db.into(db.contentCategories).insert(
          ContentCategoriesCompanion.insert(
            id: 'blob_cat',
            label: 'Blobbed',
            iconBlobKey: const Value('blob_cat_key'),
          ),
        );
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: 'blob_cat_key',
            sha256: '0' * 64,
            relativePath: relPath,
            bytes: _tinyPng.length,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final blobs = FakeBlobStore()..seed(relPath, _tinyPng);
    final theme = DisplayTheme.build();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ContentCategorySlideHeader(
            db: db,
            blobs: blobs,
            theme: theme,
            categoryId: 'blob_cat',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Blobbed'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
