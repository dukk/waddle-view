// Enforces a minimum line hit ratio on the waddlectl modules that are practical
// to unit-test on every host. Broad CLI surface area is covered indirectly via
// `cli_coverage_test`.
import 'dart:io';

const _coverageRoots = <String>{
  'lib/backup_archive_codec.dart',
  'lib/backup_fs_sync.dart',
  'lib/backup_manifest.dart',
  'lib/backup_schedule.dart',
  'lib/backup_sqlite_checkpoint.dart',
};

bool _includeSourceFile(String sf) {
  final norm = sf.replaceAll('\\', '/');
  if (!norm.startsWith('lib/')) {
    return false;
  }
  if (norm.endsWith('.g.dart')) {
    return false;
  }
  if (norm.endsWith('main.dart')) {
    return false;
  }
  return _coverageRoots.contains(norm);
}

void main(List<String> args) {
  var minPct = 85.0;
  String lcovPath = 'coverage/lcov.info';
  for (final a in args) {
    if (a.startsWith('--min=')) {
      minPct = double.parse(a.split('=').last);
    } else if (!a.startsWith('--')) {
      lcovPath = a;
    }
  }
  final raw = File(lcovPath).readAsStringSync();
  final records = raw.split('end_of_record');
  var totalLf = 0;
  var totalLh = 0;
  for (final block in records) {
    if (block.trim().isEmpty) {
      continue;
    }
    String? sf;
    var lf = 0;
    var lh = 0;
    for (final line in block.split('\n')) {
      if (line.startsWith('SF:')) {
        sf = line.substring(3).trim();
      } else if (line.startsWith('LF:')) {
        lf = int.parse(line.substring(3).trim());
      } else if (line.startsWith('LH:')) {
        lh = int.parse(line.substring(3).trim());
      }
    }
    if (sf != null && _includeSourceFile(sf.replaceAll('\\', '/'))) {
      totalLf += lf;
      totalLh += lh;
    }
  }
  if (totalLf == 0) {
    stderr.writeln(
      'No LF entries found for scoped waddlectl lib files '
      '(did you run flutter test --coverage?)',
    );
    exitCode = 1;
    return;
  }
  final pct = 100.0 * totalLh / totalLf;
  stdout.writeln(
    'Coverage (scoped waddlectl lib/): ${pct.toStringAsFixed(2)}% '
    '($totalLh / $totalLf lines)\n'
    'Files: ${_coverageRoots.join(', ')}',
  );
  if (pct + 1e-9 < minPct) {
    stderr.writeln('Below minimum ${minPct.toStringAsFixed(0)}%');
    exitCode = 1;
  }
}
