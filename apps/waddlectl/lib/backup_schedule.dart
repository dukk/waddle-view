import 'backup_archive_codec.dart';

/// Escapes [s] for use inside single quotes in POSIX `sh`.
String shellSingleQuote(String s) => "'${s.replaceAll("'", "'\\''")}'";

/// Builds `backup create ...` args (no global flags).
String backupCreateArgLine({
  required WaddleBackupArchiveFormat format,
  required String? output,
  required bool includeDatabase,
  required bool includeBlobs,
  required bool includeSecrets,
}) {
  final buf = StringBuffer(
    'backup create --format=${format == WaddleBackupArchiveFormat.zip ? 'zip' : 'tgz'}',
  );
  if (output != null && output.isNotEmpty) {
    buf.write(' --output=${shellSingleQuote(output)}');
  }
  if (!includeDatabase) {
    buf.write(' --no-include-database');
  }
  if (!includeBlobs) {
    buf.write(' --no-include-blobs');
  }
  if (!includeSecrets) {
    buf.write(' --no-include-secrets');
  }
  return buf.toString();
}

/// Optional `flock` wrapper when [lockFile] is non-empty.
String wrapWithFlock(String lockFile, String innerCommand) {
  if (lockFile.isEmpty) {
    return innerCommand;
  }
  return '/usr/bin/flock -n ${shellSingleQuote(lockFile)} -c ${shellSingleQuote(innerCommand)}';
}

/// Best-effort [OnCalendar=] for systemd when [cron] is `minute hour * * *`.
String? systemdOnCalendarFromCronOrNull(String cron) {
  final parts = cron.trim().split(RegExp(r'\s+'));
  if (parts.length != 5) {
    return null;
  }
  final m = int.tryParse(parts[0]);
  final h = int.tryParse(parts[1]);
  if (m == null || h == null) {
    return null;
  }
  if (parts[2] != '*' || parts[3] != '*' || parts[4] != '*') {
    return null;
  }
  final hh = h.toString().padLeft(2, '0');
  final mm = m.toString().padLeft(2, '0');
  return '*-*-* $hh:$mm:00';
}
