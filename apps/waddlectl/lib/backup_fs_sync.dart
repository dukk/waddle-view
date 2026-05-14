import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'backup_archive_codec.dart';

/// `media/` next to the SQLite file (same layout as the display app).
Directory mediaDirectoryNextToSqlite(File sqliteFile) =>
    Directory(p.join(sqliteFile.parent.path, 'media'));

/// Recursively lists files under [root]; keys are POSIX paths starting with `media/`.
Future<Map<String, Uint8List>> readMediaTreeForArchive(Directory root) async {
  final out = <String, Uint8List>{};
  if (!await root.exists()) {
    return out;
  }
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final rel = p.relative(entity.path, from: root.path);
    final posix = rel.replaceAll(r'\', '/');
    final key = posix == '.' || posix.isEmpty ? 'media' : 'media/$posix';
    out[key] = await entity.readAsBytes();
  }
  return out;
}

/// Deletes sibling `-wal` / `-shm` files for a main SQLite [sqliteFile] if present.
Future<void> deleteSqliteSidecarsIfPresent(File sqliteFile) async {
  final base = sqliteFile.path;
  for (final suffix in <String>['-wal', '-shm']) {
    final f = File('$base$suffix');
    if (await f.exists()) {
      await f.delete();
    }
  }
}

/// Resolves `--output`: directory vs full file path for `.zip` / `.tar.gz`.
File resolveBackupOutputPath({
  required String? outputArg,
  required WaddleBackupArchiveFormat format,
  required String timestampUtcCompact,
}) {
  final ext = format == WaddleBackupArchiveFormat.zip ? '.zip' : '.tar.gz';
  final autoName = 'waddle_backup_${timestampUtcCompact}_waddlectl$ext';
  if (outputArg == null || outputArg.isEmpty) {
    return File(p.join(Directory.current.path, autoName));
  }
  final o = outputArg;
  final lower = o.toLowerCase();
  if (lower.endsWith('.zip') || lower.endsWith('.tar.gz')) {
    return File(o);
  }
  final dir = Directory(o);
  return File(p.join(dir.path, autoName));
}

String compactTimestampUtc(DateTime utc) {
  final y = utc.year.toString().padLeft(4, '0');
  final mo = utc.month.toString().padLeft(2, '0');
  final d = utc.day.toString().padLeft(2, '0');
  final h = utc.hour.toString().padLeft(2, '0');
  final mi = utc.minute.toString().padLeft(2, '0');
  final s = utc.second.toString().padLeft(2, '0');
  return '$y$mo${d}T$h$mi${s}Z';
}

/// Recursively copies files and directories from [src] into [dst].
///
/// [dst] is created if missing. Existing files under [dst] are overwritten.
Future<void> copyDirectoryContents(Directory src, Directory dst) async {
  if (!await src.exists()) {
    return;
  }
  await dst.create(recursive: true);
  await for (final entity in src.list(recursive: true, followLinks: false)) {
    final rel = p.relative(entity.path, from: src.path);
    final destPath = p.join(dst.path, rel);
    if (entity is Directory) {
      await Directory(destPath).create(recursive: true);
    } else if (entity is File) {
      await Directory(p.dirname(destPath)).create(recursive: true);
      await entity.copy(destPath);
    }
  }
}