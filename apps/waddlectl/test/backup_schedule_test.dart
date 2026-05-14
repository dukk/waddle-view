import 'package:test/test.dart';
import 'package:waddlectl/backup_archive_codec.dart';
import 'package:waddlectl/backup_schedule.dart';

void main() {
  test('shellSingleQuote escapes quotes', () {
    expect(shellSingleQuote(r"a'b"), r"'a'\''b'");
  });

  test('wrapWithFlock uses flock -c', () {
    expect(
      wrapWithFlock('/tmp/l', 'dart run waddlectl x'),
      "/usr/bin/flock -n '/tmp/l' -c 'dart run waddlectl x'",
    );
  });

  test('systemdOnCalendarFromCronOrNull', () {
    expect(systemdOnCalendarFromCronOrNull('30 4 * * *'), '*-*-* 04:30:00');
    expect(systemdOnCalendarFromCronOrNull('0 2 * * 1'), isNull);
  });

  test('backupCreateArgLine', () {
    expect(
      backupCreateArgLine(
        format: WaddleBackupArchiveFormat.tgz,
        output: '/data/bu',
        includeDatabase: true,
        includeBlobs: false,
        includeSecrets: false,
      ),
      contains('--no-include-blobs'),
    );
  });
}
