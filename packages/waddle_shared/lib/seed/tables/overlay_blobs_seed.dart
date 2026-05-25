import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/overlay_blob_storage.dart';
import 'package:waddle_shared/persistence/tables.dart';

const _kOverlayDuckSeedAssetPrefix =
    'packages/waddle_shared/seed/assets/overlay_ducks/';

const _kDuckSeedAssetFiles = <String, String>{
  kOverlayBlobKeyDuckMascot: 'duck_mascot.svg',
  kOverlayBlobKeyDuckHeadshot1: 'duck_headshot_1.svg',
  kOverlayBlobKeyDuckHeadshot2: 'duck_headshot_2.svg',
};

/// Asset bundle prefixes: declared in [waddle_shared] pubspec and re-exported
/// from consuming apps (e.g. `waddle_display`) as `overlay_ducks/`.
const _kOverlayDuckSeedAssetPrefixes = [
  _kOverlayDuckSeedAssetPrefix,
  'overlay_ducks/',
];

Future<List<int>> readOverlayDuckSeedAssetBytes(String fileName) async {
  Object? lastError;
  for (final prefix in _kOverlayDuckSeedAssetPrefixes) {
    try {
      final data = await rootBundle.load('$prefix$fileName');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on Object catch (e) {
      lastError = e;
    }
  }
  if (!kIsWeb) {
    try {
      return _readOverlayDuckSeedBytesFromDisk(fileName);
    } on Object catch (e) {
      lastError = e;
    }
  }
  Error.throwWithStackTrace(
    lastError ?? StateError('overlay duck asset not found: $fileName'),
    StackTrace.current,
  );
}

Future<List<int>> _readOverlayDuckSeedBytesFromDisk(String fileName) async {
  final cwd = Directory.current.path;
  final candidates = [
    p.normalize(
      p.join(
        cwd,
        'packages',
        'waddle_shared',
        'seed',
        'assets',
        'overlay_ducks',
      ),
    ),
    p.normalize(
      p.join(
        cwd,
        '..',
        '..',
        'packages',
        'waddle_shared',
        'seed',
        'assets',
        'overlay_ducks',
      ),
    ),
    p.normalize(
      p.join(
        cwd,
        '..',
        'packages',
        'waddle_shared',
        'seed',
        'assets',
        'overlay_ducks',
      ),
    ),
  ];
  for (final dir in candidates) {
    final file = File(p.join(dir, fileName));
    if (await file.exists()) {
      return file.readAsBytes();
    }
  }
  throw StateError('overlay duck asset not found on disk: $fileName');
}

/// Idempotently registers duck mascot SVG blobs for `falling_images` overlays.
Future<void> ensureOverlayBlobSeed({
  required AppDatabase db,
  required BlobStore blobs,
}) async {
  for (final entry in _kDuckSeedAssetFiles.entries) {
    final existing = await (db.select(
      db.blobMetadata,
    )..where((t) => t.blobKey.equals(entry.key))).getSingleOrNull();
    if (existing != null) {
      continue;
    }
    final bytes = await readOverlayDuckSeedAssetBytes(entry.value);
    await registerOverlayBlob(
      db: db,
      blobs: blobs,
      blobKey: entry.key,
      bytes: bytes,
      mimeType: 'image/svg+xml',
    );
  }
}
