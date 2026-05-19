import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/display_image_overlay.dart';
import 'package:waddle_display/display/overlay/display_image_overlay_host.dart';
import 'package:waddle_shared/config/display_image_overlay_kv.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/fake_blob_store.dart';
import '../helpers/memory_database.dart';

final Uint8List _tinyPng = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

Future<void> _seedBlob(AppDatabase db, FakeBlobStore blobs, String blobKey) async {
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
}

void main() {
  testWidgets('DisplayImageOverlay shows image when enabled', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    const blobKey = 'overlay/pool/logo';
    final blobs = FakeBlobStore();
    await _seedBlob(db, blobs, blobKey);

    const settings = DisplayImageOverlaySettings(
      enabled: true,
      imageBlobKey: blobKey,
      x: 0.1,
      y: 0.2,
      scale: 0.15,
      opacity: 0.8,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: DisplayImageOverlay(
              settings: settings,
              blobs: blobs,
              db: db,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('display_image_overlay_raster')), findsOneWidget);
    expect(find.byType(Opacity), findsOneWidget);
  });

  testWidgets('DisplayImageOverlay hides when disabled', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: DisplayImageOverlay(
              settings: DisplayImageOverlaySettings.defaults,
              blobs: FakeBlobStore(),
              db: db,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('DisplayImageOverlayHost omits layer when KV disabled', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);

    await tester.pumpWidget(
      MaterialApp(
        home: DisplayImageOverlayHost(
          dashboardKv: const {},
          blobs: FakeBlobStore(),
          db: db,
          child: const ColoredBox(color: Colors.blue),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(DisplayImageOverlay), findsNothing);
  });

  testWidgets('DisplayImageOverlayHost shows layer from dashboard KV', (tester) async {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    await warmDatabase(db);
    const blobKey = 'overlay/pool/watermark';
    final blobs = FakeBlobStore();
    await _seedBlob(db, blobs, blobKey);

    final kv = {
      kDisplayImageOverlayKvKey: DisplayImageOverlaySettings.encodeKvValue(
        const DisplayImageOverlaySettings(
          enabled: true,
          imageBlobKey: blobKey,
          x: 0.0,
          y: 0.0,
          scale: 0.1,
          opacity: 1.0,
        ),
      ),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: DisplayImageOverlayHost(
            dashboardKv: kv,
            blobs: blobs,
            db: db,
            child: const ColoredBox(color: Colors.green),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DisplayImageOverlay), findsOneWidget);
    expect(find.byKey(const Key('display_image_overlay_raster')), findsOneWidget);
  });
}
