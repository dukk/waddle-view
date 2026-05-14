import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'backup_manifest.dart';

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
  return '$y${mo}d${d}T$h$mi${s}Z'.replaceFirst('d', ''); // bug - fix

Actually I made a typo - should be ${y}${mo}${d}T${h}${mi}${s}Z without stray d

Let me fix compactTimestampUtc in the file - I wrote broken string




StrReplace