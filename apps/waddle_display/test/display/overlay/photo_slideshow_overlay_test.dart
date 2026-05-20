import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/photo_slideshow_overlay.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_photo_slideshow_settings.dart';

import '../../helpers/fake_blob_store.dart';
import '../../helpers/memory_database.dart';

final Uint8List _tinyPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

Future<void> _seedPhoto(
  AppDatabase db,
  FakeBlobStore blobs, {
  required String id,
  required String blobKey,
}) async {
  final ref = await blobs.putBytes(_tinyPng, logicalKey: blobKey);
  await db.into(db.blobMetadata).insert(
        BlobMetadataCompanion.insert(
          blobKey: blobKey,
          sha256: 'sha',
          relativePath: ref.storageKey,
          bytes: _tinyPng.length,
          pixelWidth: const Value(800),
          pixelHeight: const Value(600),
          mimeType: const Value('image/png'),
          capturedAt: DateTime.utc(2020),
        ),
      );
  await db.into(db.photos).insert(
        PhotosCompanion.insert(
          id: id,
          mediaBlobKey: blobKey,
          photographerName: 'n',
          photographerUrl: 'https://example.com/p',
          pageUrl: 'https://example.com',
          fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      );
}

void main() {
  testWidgets('PhotoSlideshowOverlay shows raster image when photos exist',
      (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    await _seedPhoto(db, blobs, id: 'p1', blobKey: 'bk1');

    const settings = PhotoSlideshowOverlaySettings(
      x: 0.1,
      y: 0.2,
      scale: 0.15,
      opacity: 0.9,
      intervalSec: 60,
      categoryIds: [],
      aspectRatio: kPhotoSlideshowAspectAny,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: PhotoSlideshowOverlay(
              settings: settings,
              blobs: blobs,
              db: db,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const Key('photo_slideshow_overlay_raster')),
      findsOneWidget,
    );
  });

  testWidgets('PhotoSlideshowOverlay hides when no matching photos',
      (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: PhotoSlideshowOverlay(
              settings: const PhotoSlideshowOverlaySettings(
                x: 0.1,
                y: 0.2,
                scale: 0.15,
                opacity: 1,
                intervalSec: 60,
                categoryIds: ['nonexistent'],
                aspectRatio: kPhotoSlideshowAspectAny,
              ),
              blobs: FakeBlobStore(),
              db: db,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Image), findsNothing);
  });
}
