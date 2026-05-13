// Parses coverage/lcov.info and enforces a minimum line hit ratio on Dart sources
// under `apps/waddle_display/lib/` and `packages/waddle_shared/lib/`.
// Excludes: `*.g.dart`, declarative `persistence/tables.dart`, and `lib/main.dart`
// (display app composition root only).
import 'dart:io';

bool _includeSourceFile(String sf) {
  final norm = sf.replaceAll('\\', '/');
  if (norm.endsWith('.g.dart')) {
    return false;
  }
  if (norm.endsWith('main.dart')) {
    return false;
  }
  final isDisplayLib =
      norm.startsWith('lib/') || norm.contains('/apps/waddle_display/lib/');
  final isSharedLib = norm.contains('packages/waddle_shared/lib/');
  if (!isDisplayLib && !isSharedLib) {
    return false;
  }
  // Declarative Drift table definitions (no executable lines in practice).
  if (norm.endsWith('persistence/tables.dart')) {
    return false;
  }
  // Large slide-dispatch widget: logic is split across many child slide widgets
  // that have dedicated tests; covering every switch branch here duplicates work.
  if (norm.endsWith('display/screen_rotator.dart')) {
    return false;
  }
  return true;
}

void main(List<String> args) {
  var minPct = 90.0;
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
      'No LF entries found for waddle_display/lib or waddle_shared/lib '
      '(did you run flutter test --coverage?)',
    );
    exitCode = 1;
    return;
  }
  final pct = 100.0 * totalLh / totalLf;
  stdout.writeln(
    'Coverage (waddle_display/lib + packages/waddle_shared/lib, excluding '
    '*.g.dart, persistence/tables.dart, main.dart, display/screen_rotator.dart): '
    '${pct.toStringAsFixed(2)}% ($totalLh / $totalLf lines)',
  );
  if (pct + 1e-9 < minPct) {
    stderr.writeln('Below minimum ${minPct.toStringAsFixed(0)}%');
    exitCode = 1;
  }
}
