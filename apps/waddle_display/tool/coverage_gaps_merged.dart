// ignore_for_file: avoid_print
import 'dart:io';

import 'coverage_source_filter.dart';

void main(List<String> args) {
  final lcovPaths = args.isEmpty
      ? [
          'coverage/lcov.info',
          '../../../packages/waddle_shared/coverage/lcov.info',
          '../../../packages/waddle_plugin_sdk/coverage/lcov.info',
        ]
      : args;
  final rows = <List<Object>>[];
  for (final lcovPath in lcovPaths) {
    final raw = File(lcovPath).readAsStringSync();
    for (final b in raw.split('end_of_record')) {
      String? sf;
      var lf = 0, lh = 0;
      for (final line in b.split('\n')) {
        if (line.startsWith('SF:')) sf = line.substring(3).trim();
        if (line.startsWith('LF:')) lf = int.parse(line.substring(3).trim());
        if (line.startsWith('LH:')) lh = int.parse(line.substring(3).trim());
      }
      if (sf != null &&
          includeCoverageSourceFile(
            sf.replaceAll('\\', '/'),
            lcovPath: lcovPath,
          )) {
        rows.add([lf - lh, lf, lh, sf.replaceAll('\\', '/')]);
      }
    }
  }
  rows.sort((a, b) => (b[0] as int).compareTo(a[0] as int));
  var totalLf = 0, totalLh = 0;
  for (final r in rows) {
    totalLf += r[1] as int;
    totalLh += r[2] as int;
  }
  print(
    'Total: ${(100 * totalLh / totalLf).toStringAsFixed(2)}% ($totalLh / $totalLf)',
  );
  print('Need ${(totalLf * 0.82).ceil() - totalLh} more hits for 82%');
  print('');
  for (final r in rows.take(40)) {
    final miss = r[0] as int;
    if (miss <= 0) break;
    final lf = r[1] as int;
    final lh = r[2] as int;
    print(
      '${miss.toString().padLeft(5)} miss  ${(100 * lh / lf).toStringAsFixed(0).padLeft(3)}%  ${r[3]}',
    );
  }
}
