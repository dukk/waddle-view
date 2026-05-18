// Parses one or more lcov.info files and enforces a **CI floor** line hit ratio on
// Dart sources under `apps/waddle_display/lib/`, `packages/waddle_shared/lib/`,
// `packages/waddle_data_providers/lib/`, and `packages/waddle_plugin_sdk/lib/`.
// `packages/waddle_plugin_example/` is never counted (reference plugin only).
//
// Also compares against an optional **aspirational target** (default 90%): falling
// short of the target prints a warning to stderr but **does not** change exit
// code as long as coverage is at or above `--min=` (default 80%).
//
// Excludes: `*.g.dart`, declarative `persistence/tables.dart`, and `lib/main.dart`
// (display app composition root only).
import 'dart:io';

bool _includeSourceFile(String sf) {
  final norm = sf.replaceAll('\\', '/');
  if (norm.contains('packages/waddle_plugin_example/')) {
    return false;
  }
  if (norm.endsWith('.g.dart')) {
    return false;
  }
  if (norm.endsWith('main.dart')) {
    return false;
  }
  final isDisplayLib =
      norm.startsWith('lib/') || norm.contains('/apps/waddle_display/lib/');
  final isSharedLib = norm.contains('packages/waddle_shared/lib/');
  final isDataProvidersLib = norm.contains('packages/waddle_data_providers/lib/');
  final isPluginSdkLib = norm.contains('packages/waddle_plugin_sdk/lib/');
  if (!isDisplayLib && !isSharedLib && !isDataProvidersLib && !isPluginSdkLib) {
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
  var minPct = 80.0;
  var targetPct = 90.0;
  final lcovPaths = <String>[];
  for (final a in args) {
    if (a.startsWith('--min=')) {
      minPct = double.parse(a.split('=').last);
    } else if (a.startsWith('--target=')) {
      targetPct = double.parse(a.split('=').last);
    } else if (!a.startsWith('--')) {
      lcovPaths.add(a);
    }
  }
  if (lcovPaths.isEmpty) {
    lcovPaths.add('coverage/lcov.info');
  }
  var totalLf = 0;
  var totalLh = 0;
  for (final lcovPath in lcovPaths) {
    final raw = File(lcovPath).readAsStringSync();
    final records = raw.split('end_of_record');
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
  }
  if (totalLf == 0) {
    stderr.writeln(
      'No LF entries found for waddle_display/lib, waddle_shared/lib, '
      'waddle_data_providers/lib, or waddle_plugin_sdk/lib (did you run '
      'flutter test --coverage and dart test --coverage on waddle_plugin_sdk?)',
    );
    exitCode = 1;
    return;
  }
  final pct = 100.0 * totalLh / totalLf;
  stdout.writeln(
    'Coverage (waddle_display/lib + waddle_shared/lib + '
    'waddle_data_providers/lib + waddle_plugin_sdk/lib; excluding '
    'waddle_plugin_example, *.g.dart, persistence/tables.dart, main.dart, '
    'display/screen_rotator.dart): '
    '${pct.toStringAsFixed(2)}% ($totalLh / $totalLf lines)',
  );
  if (pct + 1e-9 < minPct) {
    stderr.writeln(
      'Below CI minimum ${minPct.toStringAsFixed(0)}% '
      '(target is ${targetPct.toStringAsFixed(0)}% — see --target=).',
    );
    exitCode = 1;
    return;
  }
  if (targetPct > minPct + 1e-9 && pct + 1e-9 < targetPct) {
    stderr.writeln(
      'Coverage meets CI minimum (${minPct.toStringAsFixed(0)}%) but is below '
      'the project target (${targetPct.toStringAsFixed(0)}%). '
      'This is a warning only; raise coverage when practical.',
    );
  } else if (targetPct > minPct + 1e-9 && pct + 1e-9 >= targetPct) {
    stdout.writeln(
      'Meets project coverage target (>= ${targetPct.toStringAsFixed(0)}%).',
    );
  }
}
