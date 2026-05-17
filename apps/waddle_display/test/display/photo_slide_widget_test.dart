import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_display/curator/screen_program_curator.dart';
import 'package:waddle_display/display/screens/photo/photo_slide_widget.dart';
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
  testWidgets('shows photographer attribution over image', (tester) async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final blobs = FakeBlobStore();
    final logicalKey = 'pexels/photo/7/image';
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
            id: '7',
            category: const Value('pexels'),
            mediaBlobKey: logicalKey,
            photographerName: 'Alex Shooter',
            photographerUrl: 'https://www.pexels.com/@alex',
            pexelsPageUrl: 'https://www.pexels.com/photo/7/',
            altText: const Value('Sunrise'),
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );

    const layout = ParsedWidgetSpec(
      type: 'photo',
      slot: 'main',
      config: {},
    );
    final slide = ResolvedSlide(
      screenId: 's',
      dwellMs: 5000,
      layoutJson: '',
      randomChoices: const {'main_photo': '7'},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: PhotoSlideWidget(
            db: db,
            blobs: blobs,
            slide: slide,
            spec: layout,
            theme: ThemeData.dark(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alex Shooter'), findsOneWidget);
    expect(find.textContaining('pexels.com/@alex'), findsOneWidget);
    expect(find.text('Sunrise'), findsOneWidget);
    await db.close();
  });
}
