import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:waddlectl/backup_archive_codec.dart';
import 'package:waddlectl/backup_manifest.dart';

void main() {
  test('zip round-trip manifest + file', () {
    final m = WaddleBackupManifest(
      includeDatabase: true,
      includeBlobs: true,
      includeSecrets: false,
      waddlectlVersion: 't',
      createdAtUtcIso: 'u',
    );
    final ar = buildWaddleBackupArchive(
      manifest: m,
      sqliteBytes: Uint8List.fromList([1, 2, 3]),
      secretBundleBytes: null,
      mediaRelativePosixPaths: {'media/a.bin': Uint8List(2)},
      includeEmptyMediaDirectory: false,
    );
    final bytes = encodeArchive(ar, WaddleBackupArchiveFormat.zip);
    final decoded = decodeWaddleBackupBytes(bytes);
    final m2 = readManifestFromArchive(decoded);
    expect(m2.includeDatabase, isTrue);
    expect(decoded.find('db/waddle_view.sqlite')!.readBytes(), [1, 2, 3]);
    expect(decoded.find('media/a.bin')!.readBytes()!.length, 2);
  });

  test('tgz round-trip', () {
    final m = WaddleBackupManifest(
      includeDatabase: false,
      includeBlobs: true,
      includeSecrets: false,
      waddlectlVersion: 't',
      createdAtUtcIso: 'u',
    );
    final ar = buildWaddleBackupArchive(
      manifest: m,
      sqliteBytes: null,
      secretBundleBytes: null,
      mediaRelativePosixPaths: const {},
      includeEmptyMediaDirectory: true,
    );
    final bytes = encodeArchive(ar, WaddleBackupArchiveFormat.tgz);
    final decoded = decodeWaddleBackupBytes(bytes);
    expect(readManifestFromArchive(decoded).includeBlobs, isTrue);
    expect(decoded.find('media/'), isNotNull);
  });

  test('extractArchiveToDirectory rejects traversal', () async {
    final bad = Archive()
      ..addFile(ArchiveFile.string('manifest.json', '{}'))
      ..addFile(ArchiveFile.bytes('media/../../evil.txt', Uint8List(1)));
    final tmp = Directory.systemTemp.createTempSync('waddle_bu_arc');
    addTearDown(() => tmp.deleteSync(recursive: true));
    await expectLater(
      () => extractArchiveToDirectory(bad, tmp),
      throwsA(isA<FormatException>()),
    );
  });

  test('extractArchiveToDirectory writes nested file', () async {
    final m = WaddleBackupManifest(
      includeDatabase: false,
      includeBlobs: true,
      includeSecrets: false,
      waddlectlVersion: '1',
      createdAtUtcIso: 'x',
    );
    final ar = buildWaddleBackupArchive(
      manifest: m,
      sqliteBytes: null,
      secretBundleBytes: null,
      mediaRelativePosixPaths: {
        'media/sub/x.txt': Uint8List.fromList([9]),
      },
      includeEmptyMediaDirectory: false,
    );
    final bytes = encodeArchive(ar, WaddleBackupArchiveFormat.zip);
    final decoded = decodeWaddleBackupBytes(bytes);
    final tmp = Directory.systemTemp.createTempSync('waddle_bu_ext');
    addTearDown(() => tmp.deleteSync(recursive: true));
    await extractArchiveToDirectory(decoded, tmp);
    expect(
      File(p.join(tmp.path, 'media', 'sub', 'x.txt')).readAsBytesSync(),
      [9],
    );
  });
}
