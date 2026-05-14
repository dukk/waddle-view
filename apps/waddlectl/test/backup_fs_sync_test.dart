import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:waddlectl/backup_archive_codec.dart';
import 'package:waddlectl/backup_fs_sync.dart';

void main() {
  test('resolveBackupOutputPath cwd vs dir vs file', () {
    final ts = '20260101T000000Z';
    final cwd = File(p.join(Directory.current.path, 'waddle_backup_${ts}_waddlectl.zip'));
    expect(
      resolveBackupOutputPath(
        outputArg: null,
        format: WaddleBackupArchiveFormat.zip,
        timestampUtcCompact: ts,
      ).path,
      cwd.path,
    );
    final dir = Directory.systemTemp.createTempSync('waddle_bu_out');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(
      resolveBackupOutputPath(
        outputArg: dir.path,
        format: WaddleBackupArchiveFormat.tgz,
        timestampUtcCompact: ts,
      ).path,
      p.join(dir.path, 'waddle_backup_${ts}_waddlectl.tar.gz'),
    );
    final explicit = p.join(dir.path, 'my.zip');
    expect(
      resolveBackupOutputPath(
        outputArg: explicit,
        format: WaddleBackupArchiveFormat.tgz,
        timestampUtcCompact: ts,
      ).path,
      explicit,
    );
  });
}
