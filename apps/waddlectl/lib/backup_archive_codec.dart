import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'backup_manifest.dart';

/// Output container: [zip] or gzip-compressed tar ([tgz]).
enum WaddleBackupArchiveFormat { zip, tgz }

/// Builds an in-memory [Archive] from manifest + optional payloads.
Archive buildWaddleBackupArchive({
  required WaddleBackupManifest manifest,
  Uint8List? sqliteBytes,
  Uint8List? secretBundleBytes,
  required Map<String, Uint8List> mediaRelativePosixPaths,
  required bool includeEmptyMediaDirectory,
}) {
  final archive = Archive()
    ..addFile(ArchiveFile.string(kBackupManifestPath, manifest.encodeJson()));
  if (sqliteBytes != null) {
    archive.addFile(ArchiveFile.bytes(manifest.dbArchivePath, sqliteBytes));
  }
  for (final e in mediaRelativePosixPaths.entries) {
    archive.addFile(ArchiveFile.bytes(e.key, e.value));
  }
  if (includeEmptyMediaDirectory) {
    archive.addFile(ArchiveFile.directory('media/'));
  }
  if (secretBundleBytes != null) {
    archive.addFile(
      ArchiveFile.bytes(kBackupSecretsBundlePath, secretBundleBytes),
    );
  }
  return archive;
}

Uint8List encodeArchive(Archive archive, WaddleBackupArchiveFormat format) {
  switch (format) {
    case WaddleBackupArchiveFormat.zip:
      final zipped = ZipEncoder().encode(archive);
      return Uint8List.fromList(zipped);
    case WaddleBackupArchiveFormat.tgz:
      final tarBytes = TarEncoder().encode(archive);
      return Uint8List.fromList(const GZipEncoder().encode(tarBytes));
  }
}

/// Detects format from magic bytes; decodes to a flat [Archive].
Archive decodeWaddleBackupBytes(Uint8List bytes) {
  if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4b) {
    return ZipDecoder().decodeBytes(bytes);
  }
  if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
    final tarBytes = const GZipDecoder().decodeBytes(bytes);
    return TarDecoder().decodeBytes(tarBytes);
  }
  throw const FormatException(
    'unknown backup archive (expected .zip or .tar.gz)',
  );
}

WaddleBackupManifest readManifestFromArchive(Archive archive) {
  final f = archive.find(kBackupManifestPath);
  if (f == null) {
    throw const FormatException('backup archive missing manifest.json');
  }
  final raw = f.readBytes();
  if (raw == null) {
    throw const FormatException('backup manifest could not be read');
  }
  return WaddleBackupManifest.parseJson(String.fromCharCodes(raw));
}

/// Writes every file in [archive] under [dest] (creates parent directories).
Future<void> extractArchiveToDirectory(Archive archive, Directory dest) async {
  if (!await dest.exists()) {
    await dest.create(recursive: true);
  }
  for (final file in archive) {
    final name = file.name.replaceAll(r'\', '/');
    if (name.split('/').any((s) => s == '..')) {
      throw FormatException('unsafe archive path: $name');
    }
    final outPath = p.join(dest.path, p.normalize(name));
    final base = p.normalize(dest.path);
    if (!p.isWithin(base, outPath) && p.equals(outPath, base) == false) {
      // Allow only descendants of dest (reject absolute paths / traversal).
      if (!outPath.startsWith(base + p.separator) && outPath != base) {
        throw FormatException('unsafe archive path: $name');
      }
    }
    if (file.isDirectory || name.endsWith('/')) {
      await Directory(outPath).create(recursive: true);
      continue;
    }
    final parent = Directory(p.dirname(outPath));
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final data = file.readBytes() ?? Uint8List(0);
    await File(outPath).writeAsBytes(data, flush: true);
  }
}
