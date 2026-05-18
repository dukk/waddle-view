import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/falling_images_overlay.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_falling_images_settings.dart';

import '../../helpers/fake_blob_store.dart';
import '../../helpers/memory_database.dart';

final Uint8List _tinyPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

void main() {
  testWidgets('FallingImagesOverlay eventually shows a falling image', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    const blobKey = 'overlay/pool/test-img';
    final blobs = FakeBlobStore();
    final ref = await blobs.putBytes(_tinyPng, logicalKey: blobKey);
    await db.into(db.blobMetadata).insert(
          BlobMetadataCompanion.insert(
            blobKey: blobKey,
            sha256: 'abc',
            relativePath: ref.storageKey,
            bytes: _tinyPng.length,
            mimeType: const Value('image/png'),
            capturedAt: DateTime.utc(2020),
          ),
        );

    final settings = FallingImagesScheduleSettings(
      imageBlobKeys: const [blobKey],
      dropIntervalSec: 1,
      fallSpeed: 0.5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: FallingImagesOverlay(
              settings: settings,
              blobs: blobs,
              db: db,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 2));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(Image), findsWidgets);
  });
}
